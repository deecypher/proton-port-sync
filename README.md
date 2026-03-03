# Proton Port Sync for macOS

An automated tool to synchronize Proton VPN's port forwarding with your qBittorrent client on macOS.

## 🚀 Features
- **Fully Automated**: Dynamically acquires a port from Proton VPN (via NAT-PMP) and updates qBittorrent in real-time.
- **System Safety**: Uses a private **Python Virtual Environment** (venv). It will NOT modify your system files or interfere with other Python projects.
- **Invisible Operation**: Runs as a macOS Launch Agent in the background.
- **Persistent**: Starts automatically on system login.
- **Self-Healing**: Detects network changes or process failures and recovers automatically.
- **Simple Setup**: One double-clickable installer handles all dependencies, configuration, and uninstallation.

## 📋 Requirements
- **macOS** (Tested on Sonoma/Sequoia).
- **WireGuard Client**: The official WireGuard app from the Mac App Store.
- **Proton VPN P2P Config**: You must download a WireGuard configuration file from Proton VPN that has **BOTH "Port Forwarding" (NAT-PMP) and "Moderate NAT"** enabled.
- **qBittorrent**: WebUI must be enabled in settings.

## 🛠️ Installation & Usage
1. Download the **`Proton Port Sync.command`** file.
2. Double-click the file to start the installer.
3. Follow the prompts to configure your qBittorrent WebUI settings.
4. **To Uninstall or Update**: Simply double-click the same file again.

## 📂 Troubleshooting
Logs are located at:
`~/~DIY-Scripts/Proton-Port-Sync/updater.log`

To monitor logs in real-time:
```bash
tail -f ~/~DIY-Scripts/Proton-Port-Sync/updater.log
```

The private environment is located at:
`~/~DIY-Scripts/Proton-Port-Sync/venv`

## 🔒 Security
- Configuration is stored in `~/~DIY-Scripts/Proton-Port-Sync/config.ini`.
- File permissions are automatically set to `600` (read/write only by the current user).
- Password inputs during installation are completely hidden.

## ⚖️ License
MIT License - feel free to share and modify!
