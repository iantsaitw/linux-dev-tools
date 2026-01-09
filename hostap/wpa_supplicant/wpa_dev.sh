#!/bin/bash

# --- Configuration ---
INTERFACE="wlp3s0"
SUPPLICANT="./wpa_supplicant"

# Check if config file is provided
if [ -z "$1" ]; then
    echo "Usage: ./wpa_dev.sh <config_file>"
    exit 1
fi

TARGET_CONF=$1

# --- Environment Initialization ---
echo "------------------------------------------"
echo "[*] Cleaning up existing network processes..."
sudo systemctl stop NetworkManager 2>/dev/null
sudo killall wpa_supplicant 2>/dev/null
# Ensure the interface is clean
sudo ip addr flush dev $INTERFACE
sudo ip link set $INTERFACE down
sudo ip link set $INTERFACE up
sudo iw dev $INTERFACE set power_save off

echo "------------------------------------------"
echo "[*] Starting Live Debug Mode (Foreground)"
echo "[*] Using Config: $TARGET_CONF"
echo "[*] Press Ctrl+C to stop and cleanup"
echo "------------------------------------------"

# Launch wpa_supplicant in foreground
# -K: Include key information in debug logs
# -dd: Maximum verbosity
sudo $SUPPLICANT -i $INTERFACE -D nl80211 -c "$TARGET_CONF" -t -dd -K

# --- Post-Cleanup ---
echo -e "\n\n[*] Interrupt detected, cleaning up environment..."
sudo ip addr flush dev $INTERFACE
# Optional: restart NetworkManager if you want to recover internet immediately
# sudo systemctl start NetworkManager
echo "[OK] Interface $INTERFACE IP flushed. Exit."