#!/bin/bash

# 定義模組列表（注意：順序對 insmod 非常重要）
# rmmod 時會由下往上執行，insmod 時由上往下執行
MODULES=(
    "rtw89_core"
    "rtw89_pci"
    "rtw89_8922a"
    "rtw89_8922ae"
)

echo "--- 開始重新載入 Realtek 驅動模組 ---"

# 1. 解除載入目前的模組 (從最後一個開始往回刪)
echo "[1/2] 正在移除舊模組..."
for (( i=${#MODULES[@]}-1; i>=0; i-- )); do
    MODULE=${MODULES[$i]}
    if lsmod | grep -q "$MODULE"; then
        sudo rmmod "$MODULE" && echo "  ✔ 已移除 $MODULE" || echo "  ✘ 移除 $MODULE 失敗"
    else
        echo "  - $MODULE 尚未載入，跳過"
    fi
done

# 2. 載入新的 .ko 檔案
echo "[2/2] 正在載入新模組 (.ko)..."
for MODULE in "${MODULES[@]}"; do
    FILE="./${MODULE}.ko"
    if [ -f "$FILE" ]; then
        sudo insmod "$FILE" && echo "  ✔ 已載入 $MODULE" || { echo "  ✘ 載入 $MODULE 失敗"; exit 1; }
    else
        echo "  ⚠ 錯誤: 找不到檔案 $FILE"
        exit 1
    fi
done

echo "--- 執行完畢！ ---"
ip link show | grep -E "wlan|wlp" # 顯示目前的無線網卡狀態
