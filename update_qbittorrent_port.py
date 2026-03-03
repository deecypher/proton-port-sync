import requests, logging, json, os, subprocess, time, re, threading, sys, configparser
try:
    import importlib.resources as pkg_resources
except ImportError:
    import importlib_resources as pkg_resources

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_FILE = os.path.join(SCRIPT_DIR, "updater.log")
CONFIG_FILE = os.path.join(SCRIPT_DIR, "config.ini")

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s', handlers=[logging.FileHandler(LOG_FILE, 'w')])

class PortUpdater:
    def __init__(self):
        self.config = self._load_config()
        self.latest_vpn_port, self.last_synced_port, self.vpn_thread = None, None, None
        self.port_lock = threading.Lock()
        self.stop_event = threading.Event()

    def _load_config(self):
        try:
            parser = configparser.ConfigParser()
            parser.read(CONFIG_FILE)
            return {
                'qbt_url': f"http://{parser.get('qBittorrent', 'address')}:{parser.get('qBittorrent', 'port')}",
                'qbt_user': parser.get('qBittorrent', 'username'),
                'qbt_pass': parser.get('qBittorrent', 'password'),
                'vpn_gateway': parser.get('VPN', 'gateway')
            }
        except Exception as e:
            logging.error(f"FATAL: Config error: {e}"); sys.exit(1)

    def _get_sid(self):
        try:
            resp = requests.post(f"{self.config['qbt_url']}/api/v2/auth/login", data={'username': self.config['qbt_user'], 'password': self.config['qbt_pass']}, timeout=10)
            if sid := resp.cookies.get('SID'): return sid
        except Exception as e: logging.error(f"qBt auth failed: {e}")
        return None

    def _update_qbt_port(self, sid, port):
        try:
            requests.post(f"{self.config['qbt_url']}/api/v2/app/setPreferences", cookies={'SID': sid}, data={'json': json.dumps({'listen_port': port})}, timeout=10)
            logging.info(f"Updated qBittorrent port to {port}"); return True
        except Exception as e: logging.error(f"Update failed: {e}"); return False

    def _vpn_worker(self):
        try:
            with pkg_resources.path('natpmp', 'natpmp_client.py') as natpmp_path:
                cmd = [sys.executable, str(natpmp_path), "-g", self.config['vpn_gateway'], "0", "0"]
        except Exception as e:
            logging.error(f"Resource error: {e}"); return

        port_regex = re.compile(r"public port (\d+)")
        while not self.stop_event.is_set():
            try:
                result = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True, timeout=15)
                if match := port_regex.search(result):
                    port = int(match.group(1))
                    with self.port_lock:
                        if port != self.latest_vpn_port:
                            logging.info(f"VPN Port acquired: {port}")
                            self.latest_vpn_port = port
            except Exception as e:
                if "timeout" in str(e).lower() or "unreachable" in str(e).lower(): logging.info("Waiting for VPN...")
                else: logging.error(f"VPN error: {e}")
            self.stop_event.wait(45)

    def run(self):
        logging.info("Starting Port Forwarding Updater...")
        try:
            while not self.stop_event.is_set():
                if not self.vpn_thread or not self.vpn_thread.is_alive():
                    self.vpn_thread = threading.Thread(target=self._vpn_worker, daemon=True); self.vpn_thread.start()
                with self.port_lock: port_to_check = self.latest_vpn_port
                if port_to_check and port_to_check != self.last_synced_port:
                    if sid := self._get_sid():
                        if self._update_qbt_port(sid, port_to_check): self.last_synced_port = port_to_check
                self.stop_event.wait(10)
        except KeyboardInterrupt: pass
        finally:
            self.stop_event.set()
            if self.vpn_thread: self.vpn_thread.join()
            logging.info("Shut down.")

if __name__ == "__main__":
    PortUpdater().run()
