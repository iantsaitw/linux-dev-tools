#!/bin/bash

IFACE=$1
[ -z "$IFACE" ] && { echo "Usage: sudo $0 <interface>"; exit 1; }
[[ $EUID -ne 0 ]] && { echo "Error: sudo required"; exit 1; }

IW_LINK=$(iw dev "$IFACE" link 2>/dev/null)
WPA_STATUS=$(wpa_cli -i "$IFACE" status 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$IW_LINK" ]; then
    echo "Error: Interface $IFACE is not connected."
    exit 1
fi

# Metadata
DRIVER=$( [ -L "/sys/class/net/$IFACE/device/driver" ] && basename $(readlink "/sys/class/net/$IFACE/device/driver") || echo "Unknown" )
MAC_ADDR=$(cat /sys/class/net/"$IFACE"/address 2>/dev/null)
SSID=$(echo "$IW_LINK" | grep "SSID" | head -n 1 | awk '{print $2}')
KEY_MGMT=$(echo "$WPA_STATUS" | grep "key_mgmt=" | cut -d'=' -f2)
LINKS_COUNT=$(echo "$IW_LINK" | grep -c "Link [0-9]")

# PHY Metrics
TX_RATE=$(echo "$IW_LINK" | grep "tx bitrate:" | tail -n 1 | sed 's/tx bitrate: //g' | xargs)
RX_RATE=$(echo "$IW_LINK" | grep "rx bitrate:" | tail -n 1 | sed 's/rx bitrate: //g' | xargs)
SIGNAL=$(echo "$IW_LINK" | grep "signal:" | tail -n 1 | awk '{print $2 " " $3}')

# Standard
[[ "$TX_RATE" == *"EHT"* ]] && STD="802.11be (Wi-Fi 7)" || STD="Legacy/Other"

echo "============================================================"
echo "           Wireless Interface Diagnostic Report             "
echo "============================================================"
printf "%-20s : %s\n" "Interface" "$IFACE"
printf "%-20s : %s\n" "Driver" "$DRIVER"
printf "%-20s : %s\n" "MAC Address" "$MAC_ADDR"
echo "------------------------------------------------------------"
echo " [ Link Info ]"
printf "%-20s : %s\n" "SSID" "$SSID"

if [ "$LINKS_COUNT" -gt 0 ]; then
    printf "%-20s : %s (Active)\n" "MLO Mode" "Enabled"
    # Parsing Links
    echo "$IW_LINK" | grep -E "Link [0-9]|freq:" | while read -r line; do
        if [[ $line == *"Link"* ]]; then
            L_ID=$(echo $line | awk '{print $2}')
            L_BSSID=$(echo $line | awk '{print $4}')
            read -r next_line
            L_FREQ=$(echo $next_line | awk '{print $2}')
            printf "  -> %-15s : %s MHz (BSSID: %s)\n" "Link $L_ID" "$L_FREQ" "$L_BSSID"
        fi
    done
else
    FREQ=$(echo "$IW_LINK" | grep "freq:" | awk '{print $2}')
    BSSID=$(echo "$IW_LINK" | grep "Connected to" | awk '{print $3}')
    printf "%-20s : %s MHz\n" "Frequency" "$FREQ"
    printf "%-20s : %s\n" "BSSID" "$BSSID"
fi

printf "%-20s : %s\n" "Standard" "$STD"
echo "------------------------------------------------------------"
echo " [ PHY Metrics ]"
printf "%-20s : %s\n" "Signal Level" "$SIGNAL"
printf "%-20s : %s\n" "TX Bitrate" "$TX_RATE"
printf "%-20s : %s\n" "RX Bitrate" "$RX_RATE"
echo "------------------------------------------------------------"
printf "%-20s : %s\n" "Key Management" "${KEY_MGMT:-N/A}"
echo "============================================================"