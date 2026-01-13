#!/bin/bash

# --- 1. 設定來源與目標路徑 ---
SRC_ROOT="/home/iantsai/Documents/hostap"
DEST_ROOT="/home/iantsai/Documents/linux-dev-tools/hostap"

# 檢查目標目錄是否存在
if [ ! -d "$DEST_ROOT" ]; then
    echo "[!] 錯誤：目標目錄 $DEST_ROOT 不存在！"
    exit 1
fi

echo "===================================================="
echo "[*] 開始同步 Untracked 檔案"
echo "源頭: $SRC_ROOT"
echo "目標: $DEST_ROOT"
echo "===================================================="

# --- 2. 執行複製並印出路徑 ---
# 使用 git ls-files 找出所有未追蹤檔案
git ls-files -o --exclude-standard | while read -r rel_path; do
    
    # 定義完整路徑
    SRC_FILE="$SRC_ROOT/$rel_path"
    DEST_FILE="$DEST_ROOT/$rel_path"
    
    # 取得目標目錄路徑並建立 (確保如 hostapd/ 等層級存在)
    DEST_DIR=$(dirname "$DEST_FILE")
    mkdir -p "$DEST_DIR"
    
    # 執行複製動作 (處理檔案或資料夾)
    if [ -e "$SRC_FILE" ]; then
        cp -r "$SRC_FILE" "$DEST_FILE"
        
        # --- 3. 格式化輸出 src -> dest ---
        echo "📄 [FILE] $rel_path"
        echo "   src  -> $SRC_FILE"
        echo "   dest -> $DEST_FILE"
        echo "----------------------------------------------------"
    fi
done

echo "===================================================="
echo "[OK] 所有 Untracked 檔案已成功複製！"
echo "===================================================="