#!/bin/bash

# --- 配置 ---
MON_IFACE="mon0"
# 隨便選一個 hwsim 的實體層 (通常 phy0 就看得到所有 hwsim 的通訊)
PHY_BASE=$(iw dev wlan0 info 2>/dev/null | grep wiphy | awk '{print "phy"$2}')

if [ -z "$PHY_BASE" ]; then
    echo "[!] 找不到 hwsim 網卡 (wlan0)，請確認 hwsim 已載入"
    exit 1
fi

echo "------------------------------------------------"
echo "[*] 偵測到基礎物理層: $PHY_BASE"
echo "[*] 正在建立上帝視角介面: $MON_IFACE"

# 1. 清理舊的介面
sudo iw dev $MON_IFACE del 2>/dev/null

# 2. 建立 Monitor 介面
sudo iw dev wlan0 interface add $MON_IFACE type monitor
sudo ip link set $MON_IFACE up

# 3. 提示使用者
echo "[OK] $MON_IFACE 已啟動並進入監聽模式"
echo "[*] 正在啟動 Wireshark..."
echo "[*] 提示：過濾器建議使用 'wlan.addr == 02:00:00:00:00:00'"
echo "------------------------------------------------"

# 4. 啟動 Wireshark (背景執行)
# -k: 立即開始抓包
# -i: 指定介面
sudo wireshark -i $MON_IFACE -k &

# 5. 結束時清理
trap "echo -e '\n[*] 正在移除 $MON_IFACE...'; sudo iw dev $MON_IFACE del; exit" SIGINT

echo "[!] 按下 Ctrl+C 結束監聽並移除介面"
wait