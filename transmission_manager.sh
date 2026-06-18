#!/usr/bin/env bash
# transmission_manager.sh — Transmission Daemon Manager
# An interactive TUI for managing a remote transmission-daemon over SSH.
# Usage: chmod +x transmission_manager.sh && ./transmission_manager.sh
# ─────────────────────────────────────────────────────────────────────────────
#
# Connection settings (all optional, read from the environment):
#   TR_AUTH       "user:password" for the daemon RPC. If unset you're prompted
#                 once at launch (stored for the session only).
#   TR_HOST       "host:port" of the daemon. Unset = local daemon, default port.
#   DOWNLOAD_DIR  Default download directory (for the Retrieve menu).
#                 Defaults to /var/lib/transmission-daemon/downloads.
#   SETTINGS_JSON Path to settings.json. Defaults to the Debian/Ubuntu location.
#
# This tool does not run as root for transmission commands. A handful of system
# checks (VPN, port binding, daemon control, reading settings.json) call sudo
# themselves only where genuinely needed — you do NOT need to launch with sudo.

TM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tm"

if [ ! -d "$TM_DIR" ]; then
    echo "Error: tm/ directory not found alongside transmission_manager.sh"
    echo "Expected: $TM_DIR"
    exit 1
fi

if ! command -v transmission-remote >/dev/null 2>&1; then
    echo "Error: transmission-remote is not installed or not on PATH."
    echo "Install it with:  sudo apt install transmission-cli   (Debian/Ubuntu)"
    exit 1
fi

# Source modules in dependency order
source "$TM_DIR/lib.sh"
source "$TM_DIR/actions.sh"
source "$TM_DIR/menu.sh"

# Make sure we have credentials before entering the alternate-screen menu
prompt_auth

# Launch
run_menu
