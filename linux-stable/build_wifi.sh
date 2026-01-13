#!/bin/bash

# 1. 路徑定義
KERNEL_ROOT="/home/iantsai/Documents/linux-stable"
WIRELESS_DIR="$KERNEL_ROOT/net/wireless"
MAC80211_DIR="$KERNEL_ROOT/net/mac80211"
RTW89_DIR="$KERNEL_ROOT/drivers/net/wireless/realtek/rtw89"

# 2. 判斷模式
DO_CLEAN=false
if [ "$1" == "clean" ]; then
    DO_CLEAN=true
    echo -e "\e[1;33m🧹 [Mode] Clean build enabled.\e[0m"
else
    echo -e "\e[1;32m🚀 [Mode] Incremental build.\e[0m"
fi

echo "--------------------------------------------------------"

# --- 第一階段：編譯 cfg80211 ---
echo -e "\e[1;34m📂 [1/3] Processing cfg80211: $WIRELESS_DIR\e[0m"
[ "$DO_CLEAN" = true ] && make -C "$WIRELESS_DIR" -f Makefile.local clean
make -C "$WIRELESS_DIR" -f Makefile.local -j$(nproc)
if [ $? -ne 0 ]; then echo -e "\e[1;31m❌ Error in cfg80211\e[0m"; exit 1; fi

# --- 第二階段：編譯 mac80211 (需要 cfg80211 的符號) ---
echo -e "\e[1;34m📂 [2/3] Processing mac80211: $MAC80211_DIR\e[0m"
[ "$DO_CLEAN" = true ] && make -C "$MAC80211_DIR" -f Makefile.local clean
# 傳入 cfg80211 的符號表
make -C "$MAC80211_DIR" -f Makefile.local -j$(nproc) \
     KBUILD_EXTRA_SYMBOLS="$WIRELESS_DIR/Module.symvers"
if [ $? -ne 0 ]; then echo -e "\e[1;31m❌ Error in mac80211\e[0m"; exit 1; fi

# --- 第三階段：編譯 rtw89 (需要 cfg80211 + mac80211 的符號) ---
echo -e "\e[1;34m📂 [3/3] Processing rtw89: $RTW89_DIR\e[0m"
[ "$DO_CLEAN" = true ] && make -C "$RTW89_DIR" -f Makefile.local clean
# 傳入兩者的符號表 (用空格隔開)
make -C "$RTW89_DIR" -f Makefile.local -j$(nproc) \
     KBUILD_EXTRA_SYMBOLS="$WIRELESS_DIR/Module.symvers $MAC80211_DIR/Module.symvers"
if [ $? -ne 0 ]; then echo -e "\e[1;31m❌ Error in rtw89\e[0m"; exit 1; fi

# --------------------------------------------------------

# 4. 最終狀態總結
KO_FILES=(
    "$WIRELESS_DIR/cfg80211.ko"
    "$MAC80211_DIR/mac80211.ko"
    "$RTW89_DIR/rtw89_core.ko"
    "$RTW89_DIR/rtw89_pci.ko"
    "$RTW89_DIR/rtw89_8922a.ko"
    "$RTW89_DIR/rtw89_8922ae.ko"
)

echo -e "\n========================================================"
echo -e "📊  FINAL BUILD SUMMARY"
echo -e "========================================================"
printf "%-18s %-10s %-20s\n" "Module" "Status" "Last Build Time"
echo "--------------------------------------------------------"

for KO in "${KO_FILES[@]}"; do
    MOD_NAME=$(basename "$KO")
    if [ -f "$KO" ]; then
        BUILD_TIME=$(date -r "$KO" "+%m/%d %H:%M")
        printf "\e[32m%-18s %-10s %-20s\e[0m\n" "$MOD_NAME" "Ready" "$BUILD_TIME"
    else
        printf "\e[31m%-18s %-10s %-20s\e[0m\n" "$MOD_NAME" "MISSING" "N/A"
    fi
done
echo -e "========================================================\n"