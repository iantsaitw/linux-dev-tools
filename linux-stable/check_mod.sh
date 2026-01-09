#!/bin/bash

DEV_PATH="/home/iantsai/Documents/linux-stable"
DEV_KO_PCI="$DEV_PATH/drivers/net/wireless/realtek/rtw89/rtw89_pci.ko"
DEV_KO_MAC="$DEV_PATH/net/mac80211/mac80211.ko"
DEV_KO_CFG="$DEV_PATH/net/wireless/cfg80211.ko"

echo "==========================================="
echo "🔍 Wi-Fi 驅動指紋與環境檢查"
echo "==========================================="

check_fingerprint() {
    local mod_name=$1
    local dev_file=$2
    
    echo "[$mod_name]"
    
    if [ -d "/sys/module/$mod_name" ]; then
        MEM_VER=$(cat "/sys/module/$mod_name/srcversion" 2>/dev/null)
        echo "  核心指紋: $MEM_VER"
    else
        echo "  核心指紋: [ 模組未載入 ]"
        echo ""
        return
    fi

    if [ -f "$dev_file" ]; then
        DISK_VER=$(modinfo -F srcversion "$dev_file" 2>/dev/null)
        echo "  檔案指紋: $DISK_VER"
        
        if [ "$MEM_VER" == "$DISK_VER" ]; then
            echo "  >> 🟢 狀態: 一致 (開發版)"
        else
            echo "  >> 🟡 狀態: 不一致 (原生/舊版)"
        fi
    else
        echo "  >> 📂 檔案: 找不到 .ko 檔"
    fi
    echo ""
}

check_fingerprint "cfg80211" "$DEV_KO_CFG"
check_fingerprint "mac80211" "$DEV_KO_MAC"
check_fingerprint "rtw89_pci" "$DEV_KO_PCI"

WLAN_INTF=$(ip -br link show | awk '{print $1}' | grep -E "^w" | head -n 1)
if [ -n "$WLAN_INTF" ]; then
    REG=$(iw reg get | grep "country" | awk '{print $2}' | tr -d ':')
    echo "-------------------------------------------"
    echo "網卡: $WLAN_INTF | 法規: $REG"
fi
echo "==========================================="