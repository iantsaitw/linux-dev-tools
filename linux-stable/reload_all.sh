#!/bin/bash

# ==========================================
# 核心開發用：Wi-Fi 驅動重新載入工具 (RTK + HWSIM 整合版)
# ==========================================

# 1. 路徑與模組定義
KERNEL_ROOT="/home/iantsai/Documents/linux-stable"
RTW89_DIR="$KERNEL_ROOT/drivers/net/wireless/realtek/rtw89"
HWSIM_DIR="$KERNEL_ROOT/drivers/net/wireless/virtual"

# 依賴順序定義
# 解除安裝 (rmmod) 時會倒序執行；載入 (insmod) 時會順序執行
MODULES_BASE=(
    "cfg80211"
    "mac80211"
)

MODULES_HWSIM=(
    "mac80211_hwsim"
)

MODULES_RTW=(
    "rtw89_core"
    "rtw89_pci"
    "rtw89_8922a"
    "rtw89_8922ae"
)

# 合併所有模組清單，定義正確的層次結構
# 底層 -> 高層
ALL_LOAD_ORDER=("${MODULES_BASE[@]}" "${MODULES_HWSIM[@]}" "${MODULES_RTW[@]}")

echo "--- 🔄 開始重新載入 Wi-Fi 開發環境 (HWSIM + RTW89) ---"

# 2. 移除舊模組 (由最上層往下層移除)
echo "[1/3] 正在清理現有模組..."
for (( i=${#ALL_LOAD_ORDER[@]}-1; i>=0; i-- )); do
    MOD=${ALL_LOAD_ORDER[$i]}
    if lsmod | grep -q "^$MOD"; then
        sudo rmmod "$MOD" 2>/dev/null && echo "  ✔ 已移除 $MOD" || {
            echo "  ✘ 移除 $MOD 失敗，嘗試強制移除..."
            sudo rmmod -f "$MOD" 2>/dev/null
        }
    fi
done

# 3. 載入新模組 (由最下層往上層載入)
echo "[2/3] 正在載入新編譯的 .ko..."

# A. 載入基礎層 (cfg80211 -> mac80211)
sudo insmod "$KERNEL_ROOT/net/wireless/cfg80211.ko" && echo "  ✔ 載入 cfg80211"
sudo insmod "$KERNEL_ROOT/net/mac80211/mac80211.ko" && echo "  ✔ 載入 mac80211"

# B. 載入模擬器層
if [ -f "$HWSIM_DIR/mac80211_hwsim.ko" ]; then
    sudo insmod "$HWSIM_DIR/mac80211_hwsim.ko" radios=2 && echo "  ✔ 載入 mac80211_hwsim (2 Radios)"
else
    echo "  ⚠ 警告: 找不到 hwsim.ko，跳過模擬器載入。"
fi

# C. 載入 Realtek 驅動層
for MOD in "${MODULES_RTW[@]}"; do
    FILE="$RTW89_DIR/${MOD}.ko"
    if [ -f "$FILE" ]; then
        sudo insmod "$FILE" && echo "  ✔ 載入 $MOD" || { echo "  ✘ 載入 $MOD 失敗"; exit 1; }
    else
        echo "  ⚠ 錯誤: 找不到 $FILE，RTK 載入中斷。"
        exit 1
    fi
done

# 4. 同步網路介面與服務
echo "[3/3] 正在同步網路介面狀態..."

# 重新讀取 systemd 配置，防止 wpa_supplicant 警告
sudo systemctl daemon-reload
sudo systemctl restart wpa_supplicant

# 獲取所有無線介面 (hwsim + rtw89)
WLAN_INTERFACES=$(ip -br link show | awk '{print $1}' | grep -E "^w")

if [ -n "$WLAN_INTERFACES" ]; then
    for IFACE in $WLAN_INTERFACES; do
        echo "  📡 處理介面: $IFACE"
        sudo ip link set "$IFACE" up
        # 如果是實體網卡 (假設是 wlo1 或特定名稱)，讓 NM 管理；
        # 如果是模擬網卡 (wlan0/1)，通常開發用，可設為 unmanaged 以免干擾
        if [[ "$IFACE" == "wlan"* ]]; then
            nmcli device set "$IFACE" managed no 2>/dev/null
            echo "    (已將 $IFACE 設為 unmanaged 以利開發測試)"
        else
            nmcli device set "$IFACE" managed yes 2>/dev/null
        fi
    done
    echo "--- ✅ 驅動重載完成 ---"
else
    echo "  ⚠️ 警告: 找不到任何無線介面！請檢查 dmesg。"
fi

# 最後顯示 dmesg 相關訊息
echo "--------------------------------------------------------"
sudo dmesg | tail -n 20 | grep -E "hwsim|rtw89|cfg80211|mac80211|Hello|IAN_DEBUG"