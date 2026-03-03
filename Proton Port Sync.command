#!/bin/zsh

# Proton Port Sync
# Unified Installer & Uninstaller for macOS.
# This script uses a Python Virtual Environment for maximum system safety.

# --- Configuration ---
INSTALL_DIR="$HOME/~DIY-Scripts/Proton-Port-Sync"
VENV_DIR="$INSTALL_DIR/venv"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_FILENAME="com.user.protonvpnupdater.plist"
PYTHON_SCRIPT_FILENAME="update_qbittorrent_port.py"
CONFIG_FILENAME="config.ini"
LOG_FILENAME="updater.log"
PLIST_PATH="$PLIST_DIR/$PLIST_FILENAME"

# --- Helper Functions ---
echo_bold() { echo -e "\033[1m$1\033[0m"; }
echo_green() { echo -e "\033[0;32m$1\033[0m"; }
echo_yellow() { echo -e "\033[0;33m$1\033[0m"; }
echo_error() { echo -e "\033[0;31mERROR: $1\033[0m" >&2; }

# Reliable input function with defaults
get_input() {
    local prompt="$1"
    local default_value="$2"
    local input=""
    
    echo -n "$prompt [$default_value]: " >&2
    read input
    echo "${input:-$default_value}"
}

# --- Main Logic ---

clear
echo_bold "=========================================="
echo_bold "       Proton Port Sync for macOS         "
echo_bold "=========================================="
echo ""

# 1. Smart Detection
if [ -f "$PLIST_PATH" ]; then
    echo_yellow "Proton Port Sync is already installed."
    echo "1) Update settings or Reinstall"
    echo "2) Uninstall"
    echo "3) Quit"
    echo ""
    echo "Press ENTER to accept defaults, or type to change them."
    echo -n "Select an option [1]: "
    read CHOICE
    CHOICE=${CHOICE:-1}
    echo ""
    if [[ "$CHOICE" == "2" ]]; then
        echo ""
        echo_green "Uninstalling Proton Port Sync..."
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        rm -f "$PLIST_PATH"
        rm -rf "$INSTALL_DIR"
        echo ""
        echo_bold "Uninstall complete."
        exit 0
    elif [[ "$CHOICE" == "3" ]]; then
        exit 0
    fi
    echo ""
    echo_green "Refreshing installation..."
fi

# 2. Introduction
echo "This script automates Proton VPN port forwarding for qBittorrent on macOS."
echo "It works invisibly in the background and persists through system restarts."
echo ""
echo_yellow "IMPORTANT: This requires the official WireGuard app from the Mac App Store."
echo_yellow "Ensure you have it installed and have downloaded your Proton P2P config files."
echo ""
echo_yellow "SYSTEM SAFETY: This installer uses a private Virtual Environment."
echo_yellow "It will NOT modify your system Python or interfere with other projects."
echo ""
echo -n "Ready to proceed? (y/n) [y]: "
read result
result=${result:-y}
if [[ ! "$result" =~ ^[Yy]$ ]]; then
    echo "Exiting..."
    exit 0
fi

echo -n "Is the WireGuard client installed from the Mac App Store? (y/n) [y]: "
read result
result=${result:-y}
if [[ ! "$result" =~ ^[Yy]$ ]]; then
    echo ""
    echo_yellow "Please install WireGuard from the Mac App Store and run this script again."
    echo "Link: https://apps.apple.com/app/wireguard/id1451685025"
    echo ""
    exit 0
fi

echo ""
echo_green "Initializing Setup..."

# 3. Xcode Command Line Tools Check
if ! xcode-select -p &>/dev/null; then
    echo_yellow "Xcode Command Line Tools are required but missing."
    echo -n "Install them now? This can take 10-20 mins. Apologies for the wait! (y/n) [y]: "
    read result
    result=${result:-y}
    echo ""
    if [[ ! "$result" =~ ^[Yy]$ ]]; then echo_error "Cannot continue without tools. Exiting."; exit 1; fi

    echo_green "A macOS system pop-up will now appear."
    echo_green "Please click 'Install' and follow the instructions."
    echo ""
    
    # Trigger the system installer
    xcode-select --install &>/dev/null
    
    # Wait for the installation to complete
    echo -n "Waiting for installation to finish... "
    local sp='/-\|'
    local i=1
    until xcode-select -p &>/dev/null; do
        printf "\b%s" "${sp[$(( (i % 4) + 1 ))]}"
        i=$(( i + 1 ))
        sleep 1
    done
    echo ""
    echo_green "Command Line Tools installed successfully."
fi

# 4. Homebrew Installation
if ! command -v brew &> /dev/null; then
    echo_yellow "Homebrew is required but not found."
    echo -n "Install Homebrew now? (y/n) [y]: "
    read result
    result=${result:-y}
    echo ""
    if [[ ! "$result" =~ ^[Yy]$ ]]; then echo_error "Cannot continue without Homebrew. Exiting."; exit 1; fi

    echo_green "Installing Homebrew... Administrative privileges required."
    sudo -v
    echo_green "Note: Showing live Homebrew installation progress below."
    echo ""
    /bin/bash -c "echo '' | $(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -x "/opt/homebrew/bin/brew" ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
fi

# 5. Python 3 Check
if ! command -v python3 &> /dev/null; then
    echo_green "Installing Python 3 via Homebrew..."
    brew install python
fi

BASE_PYTHON=$(command -v python3)
echo "Found environment: $BASE_PYTHON"

# 6. Setup Virtual Environment
echo_green "Preparing private Virtual Environment..."
mkdir -p "$INSTALL_DIR"
"$BASE_PYTHON" -m venv "$VENV_DIR"
VENV_PYTHON="$VENV_DIR/bin/python3"

# 7. Install Libraries in VENV
echo_green "Synchronizing required libraries..."
"$VENV_PYTHON" -m pip install --upgrade pip > /dev/null
"$VENV_PYTHON" -m pip install requests py-natpmp "importlib-resources; python_version < '3.9'" > /dev/null

# 8. Gather Configuration
echo ""
echo_bold "--- Configuration ---"
echo "Press ENTER to accept defaults, or type to change them."
echo ""

QBT_ADDR=$(get_input "qBittorrent WebUI Address" "localhost")
QBT_PORT=$(get_input "qBittorrent WebUI Port" "8080")
QBT_USER=$(get_input "qBittorrent WebUI Username" "admin")

while true; do
    echo -n "qBittorrent WebUI Password: "
    read -s QBT_PASS
    echo ""
    if [ -z "$QBT_PASS" ]; then
        echo_yellow "Warning: Password is blank."
        echo -n "Continue anyway? (y/n) [y]: "
        read PASS_CONFIRM
        PASS_CONFIRM=${PASS_CONFIRM:-y}
        if [[ "$PASS_CONFIRM" =~ ^[Yy]$ ]]; then break; fi
    else
        break
    fi
done

VPN_GATEWAY="10.2.0.1"

# 9. Create Files
echo ""
echo_green "Finalizing installation..."
PYTHON_SCRIPT_PATH="$INSTALL_DIR/$PYTHON_SCRIPT_FILENAME"
CONFIG_PATH="$INSTALL_DIR/$CONFIG_FILENAME"

cat > "$CONFIG_PATH" << EOF
[qBittorrent]
address = $QBT_ADDR
port = $QBT_PORT
username = $QBT_USER
password = $QBT_PASS

[VPN]
gateway = $VPN_GATEWAY
EOF
chmod 600 "$CONFIG_PATH"

cat > "$PYTHON_SCRIPT_PATH" << 'EOF'
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
EOF

mkdir -p "$PLIST_DIR"
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.user.protonvpnupdater</string>
    <key>ProgramArguments</key>
    <array>
        <string>$VENV_PYTHON</string>
        <string>$PYTHON_SCRIPT_PATH</string>
    </array>
    <key>KeepAlive</key><true/><key>RunAtLoad</key><true/>
    <key>WorkingDirectory</key><string>$INSTALL_DIR</string>
    <key>StandardOutPath</key><string>$INSTALL_DIR/$LOG_FILENAME</string>
    <key>StandardErrorPath</key><string>$INSTALL_DIR/$LOG_FILENAME</string>
</dict>
</plist>
EOF

# 10. Start
echo_green "Starting background service..."
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo ""
echo_bold "=========================================="
echo_bold "            SETUP COMPLETE!               "
echo_bold "=========================================="
echo ""
echo "The Port Sync service is now running in the background."
echo "Log file: ~/~DIY-Scripts/Proton-Port-Sync/updater.log"
echo ""
echo "To update or uninstall, simply re-run this script."
echo ""
