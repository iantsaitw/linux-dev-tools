#!/bin/bash

# --- Configuration ---
INTERFACE="wlan0"
SUPPLICANT="./wpa_supplicant"
LOG_FILE="wpa_debug.log"
OLD_LOG="${LOG_FILE}.old"

# Network Settings
STATIC_IP="192.168.10.2/24"
AP_IP="192.168.10.1"

if [ -z "$1" ]; then
    echo "Usage: ./wpa_stable.sh <config_file>"
    exit 1
fi

TARGET_CONF=$1

# --- Function: Connection Monitor ---
check_and_monitor() {
    echo "[*] Monitoring connection state..."
    local count=0
    local max_wait=20
    
    while [ $count -lt $max_wait ]; do
        local raw_status=$(sudo ./wpa_cli -i $INTERFACE status 2>/dev/null)
        local current_state=$(echo "$raw_status" | grep "wpa_state=" | cut -d= -f2)
        
        if [[ "$current_state" == "COMPLETED" ]]; then
            echo -e "\n[✓] L2 Connected (Completed)!"
            
            # --- IP Provisioning ---
            echo "[*] Setting Static IP: $STATIC_IP..."
            sudo ip addr add $STATIC_IP dev $INTERFACE 2>/dev/null
            
            local iw_link=$(sudo iw dev $INTERFACE link)
            echo "--------- Connection Summary ---------"
            echo "SSID   : $(echo "$raw_status" | grep "^ssid=" | cut -d= -f2)"
            echo "BSSID  : $(echo "$raw_status" | grep "^bssid=" | cut -d= -f2)"
            echo "Signal : $(echo "$iw_link" | grep "signal:" | awk '{print $2, $3}')"
            echo "Rate   : $(echo "$iw_link" | grep "tx bitrate:" | sed 's/^[ \t]*//')"
            echo "--------------------------------------"
            
            echo "[*] Testing Reachability to AP ($AP_IP)..."
            if ping -c 3 $AP_IP > /dev/null; then
                echo "[✓] Ping Success!"
                echo "[*] Starting Continuous Ping. (Press Ctrl+C to return to menu)"
                ping $AP_IP
            else
                echo "[!] Ping Failed! Check if AP IP $AP_IP is correct."
            fi
            return 0
        fi
        echo -ne "\r[Status: ${current_state:-SCANNING}] [Wait: $((max_wait-count))s]...   "
        sleep 1
        ((count++))
    done
    echo -e "\n[!] Connection attempt timed out."
    return 1
}

# --- Initialization ---
echo "=========================================="
echo "   Wi-Fi Dev Tool - Stable Version"
echo "=========================================="

# 1. Log Rotation
if [ -f "$LOG_FILE" ]; then
    echo "[*] Rotating old log to $OLD_LOG"
    mv "$LOG_FILE" "$OLD_LOG"
fi

# 2. Network Cleanup
sudo systemctl stop NetworkManager 2>/dev/null
sudo killall wpa_supplicant 2>/dev/null
sudo ip addr flush dev $INTERFACE
sudo ip link set $INTERFACE up
sudo iw dev $INTERFACE set power_save off

# 3. Start Supplicant
echo "[*] Launching $SUPPLICANT..."
# -B: Background, -t: Include timestamp, -f: Log to file
sudo $SUPPLICANT -i $INTERFACE -D nl80211 -c "$TARGET_CONF" -B -t -dd -f "$LOG_FILE"
sleep 1
sudo chown $USER:$USER "$LOG_FILE"

echo "[TIP] To see live logs, run this in another terminal:"
echo "      tail -f $(pwd)/$LOG_FILE"
echo "------------------------------------------"

# Auto-connect on start
check_and_monitor

# --- Menu Loop ---
while true; do
    echo ""
    echo ">> Menu: [c]onnect | [d]isconnect | [r]estart | [l]og_clear | [q]uit"
    read -p ">> Action: " opt

    case $opt in
        [Cc]* ) 
            sudo ./wpa_cli -i $INTERFACE reassociate > /dev/null
            check_and_monitor
            ;;
        [Dd]* ) 
            sudo ./wpa_cli -i $INTERFACE disconnect > /dev/null
            sudo ip addr flush dev $INTERFACE
            echo "[*] Disconnected and IP flushed." 
            ;;
        [Rr]* ) 
            sudo killall wpa_supplicant 2>/dev/null
            exec "$0" "$TARGET_CONF" 
            ;;
        [Ll]* )
            > "$LOG_FILE"
            echo "[*] Log file cleared."
            ;;
        [Qq]* ) 
            echo "[*] Cleaning up and Exiting..."
            sudo killall wpa_supplicant 2>/dev/null
            exit 0 
            ;;
        * ) echo "Invalid option." ;;
    esac
done
