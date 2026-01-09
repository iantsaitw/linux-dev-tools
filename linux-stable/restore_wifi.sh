#!/bin/bash

# ==========================================
# 系統復原用：恢復 Ubuntu 原生無線驅動 (通用版)
# ==========================================

echo "--- 🛠️ 開始強力恢復系統原生無線驅動 ---"

# 1. 停止網路相關服務，防止移除時被佔用
echo "[1/3] 停止網路管理服務..."
sudo systemctl stop NetworkManager
sudo systemctl stop wpa_supplicant

# 2. 嚴格依照依賴順序解除載入 (由上層往下層)
# 這樣可以避免 "Module is in use" 的錯誤
echo "[2/3] 正在由上而下移除所有 Wi-Fi 模組..."

# 定義所有可能相關的模組名稱
MODULES_TO_REMOVE=(
    "rtw89_8922ae"
    "rtw89_8922a"
    "rtw89_pci"
    "rtw89_core"
    "mac80211"
    "cfg80211"
)

for MOD in "${MODULES_TO_REMOVE[@]}"; do
    if lsmod | grep -q "^$MOD"; then
        echo "  正在移除: $MOD"
        # 先嘗試正常移除，失敗則嘗試強力移除
        sudo rmmod "$MOD" 2>/dev/null || sudo rmmod -f "$MOD" 2>/dev/null
    fi
done

# 3. 載入系統原生驅動
# 使用 modprobe 而非指定路徑，這樣系統會去 /lib/modules/ 找原廠驅動
echo "[3/3] 重新載入系統原生模組 (modprobe)..."
sudo modprobe rtw89_8922ae

# 4. 偵測介面並啟動服務
WLAN_INTF=$(ip -br link show | awk '{print $1}' | grep -E "^w" | head -n 1)

if [ -n "$WLAN_INTF" ]; then
    echo "  📡 偵測到原生網卡介面: $WLAN_INTF"
    sudo ip link set "$WLAN_INTF" up
    sudo rfkill unblock wifi
fi

# 重新啟動服務
echo "[*] 啟動網路管理服務..."
sudo systemctl start wpa_supplicant
sudo systemctl start NetworkManager

echo "--- ✅ 復原完成！ ---"
echo "請等待 5-10 秒，系統將自動連線至原本的 Wi-Fi。"

# 驗證狀態
if [ -n "$WLAN_INTF" ]; then
    nmcli device status | grep "$WLAN_INTF"
fi