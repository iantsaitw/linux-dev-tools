#!/bin/bash

# ==========================================
# 核心開發用：Wi-Fi 驅動重新載入工具 (通用版)
# ==========================================

# 1. 路徑與模組定義
KERNEL_ROOT="/home/iantsai/Documents/linux-stable"
RTW89_DIR="$KERNEL_ROOT/drivers/net/wireless/realtek/rtw89"

# 依賴順序：下層在前，上層在後
# (insmod 依序執行, rmmod 倒序執行)
MODULES_BASE=(
    "cfg80211"
    "mac80211"
)
MODULES_RTW=(
    "rtw89_core"
    "rtw89_pci"
    "rtw89_8922a"
    "rtw89_8922ae"
)

ALL_MODULES=("${MODULES_BASE[@]}" "${MODULES_RTW[@]}")

echo "--- 🔄 開始重新載入 Wi-Fi 驅動體系 ---"

# 2. 移除舊模組 (由上層往下層)
echo "[1/3] 正在移除舊模組..."
for (( i=${#ALL_MODULES[@]}-1; i>=0; i-- )); do
    MOD=${ALL_MODULES[$i]}
    if lsmod | grep -q "^$MOD"; then
        sudo rmmod "$MOD" && echo "  ✔ 已移除 $MOD" || {
            echo "  ✘ 移除 $MOD 失敗，嘗試強力移除..."
            sudo rmmod -f "$MOD"
        }
    fi
done

# 3. 載入新模組 (由下層往上層)
echo "[2/3] 正在從編譯目錄載入新 .ko..."

# 載入基礎無線層
sudo insmod "$KERNEL_ROOT/net/wireless/cfg80211.ko" && echo "  ✔ 載入 cfg80211"
sudo insmod "$KERNEL_ROOT/net/mac80211/mac80211.ko" && echo "  ✔ 載入 mac80211"

# 載入 rtw89 驅動層
for MOD in "${MODULES_RTW[@]}"; do
    FILE="$RTW89_DIR/${MOD}.ko"
    if [ -f "$FILE" ]; then
        sudo insmod "$FILE" && echo "  ✔ 載入 $MOD" || { echo "  ✘ 載入 $MOD 失敗"; exit 1; }
    else
        echo "  ⚠ 錯誤: 找不到 $FILE"
        exit 1
    fi
done

# 4. 偵測介面與同步狀態
echo "[3/3] 正在同步網路介面狀態..."

# 自動偵測介面名稱 (抓取第一個以 'w' 開頭的無線網卡)
WLAN_INTF=$(ip -br link show | awk '{print $1}' | grep -E "^w" | head -n 1)

if [ -n "$WLAN_INTF" ]; then
    echo "  📡 偵測到網卡: $WLAN_INTF"
    
    # 重啟 wpa_supplicant 是讓 UI (NetworkManager) 重新認得驅動的關鍵
    sudo systemctl restart wpa_supplicant
    
    # 確保介面是開啟的並讓 NetworkManager 接管
    sudo ip link set "$WLAN_INTF" up
    nmcli device set "$WLAN_INTF" managed yes 2>/dev/null
    
    echo "--- ✅ $WLAN_INTF 重載完成，UI 應會在幾秒內恢復 ---"
else
    echo "  ⚠️ 警告: 找不到無線介面！請檢查 dmesg 確認硬體初始化是否成功。"
fi

# 最後顯示 dmesg 相關訊息供開發參考
echo "--------------------------------------------------------"
sudo dmesg | tail -n 15 | grep -E "rtw89|cfg80211|mac80211"