#!/bin/bash

# 1. 路徑定義
KERNEL_ROOT="/home/iantsai/Documents/linux-stable"
WIRELESS_DIR="$KERNEL_ROOT/net/wireless"
MAC80211_DIR="$KERNEL_ROOT/net/mac80211"
RTW89_DIR="$KERNEL_ROOT/drivers/net/wireless/realtek/rtw89"

TARGET_DIRS=(
    "$WIRELESS_DIR"
    "$MAC80211_DIR"
    "$RTW89_DIR"
)

# 定義最終產出的 .ko 檔案路徑
KO_FILES=(
    "$WIRELESS_DIR/cfg80211.ko"
    "$MAC80211_DIR/mac80211.ko"
    "$RTW89_DIR/rtw89_core.ko"
    "$RTW89_DIR/rtw89_pci.ko"
    "$RTW89_DIR/rtw89_8922a.ko"
    "$RTW89_DIR/rtw89_8922ae.ko"
)

# 2. 判斷模式
DO_CLEAN=false
if [ "$1" == "clean" ]; then
    DO_CLEAN=true
    echo -e "\e[1;33m🧹 [Mode] Clean build enabled.\e[0m"
else
    echo -e "\e[1;32m🚀 [Mode] Incremental build.\e[0m"
fi

echo "--------------------------------------------------------"

# 3. 執行編譯循環
for DIR in "${TARGET_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        echo -e "\e[1;34m📂 Processing Directory: $DIR\e[0m"
        
        # 執行 Clean (不再靜音，讓你看得到清除動作)
        if [ "$DO_CLEAN" = true ]; then
            make -C "$DIR" -f Makefile.local clean
        fi

        # 針對 rtw89 傳入符號表
        EXTRA_SYMS_ARG=""
        [[ "$DIR" == *"/rtw89"* ]] && EXTRA_SYMS_ARG="KBUILD_EXTRA_SYMBOLS=$WIRELESS_DIR/Module.symvers"

        # 執行編譯 (移除 > /dev/null，保留所有輸出)
        make -C "$DIR" -f Makefile.local -j$(nproc) $EXTRA_SYMS_ARG
        
        # 檢查編譯結果
        if [ $? -eq 0 ]; then
            echo -e "\e[32m  ✔ $(basename $DIR) compilation finished.\e[0m"
        else
            echo -e "\n\e[1;31m❌ Error: Compilation failed in $DIR\e[0m"
            echo "請向上捲動查看具體錯誤訊息。"
            exit 1
        fi
        echo "--------------------------------------------------------"
    fi
done

# 4. 最終狀態總結 (Summary) - 只有成功才會走到這
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