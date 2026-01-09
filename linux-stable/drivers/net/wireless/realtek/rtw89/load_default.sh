#!/bin/bash

echo "正在移除目前載入的模組..."
# 強制移除所有相關模組
sudo rmmod rtw89_8922ae rtw89_8922a rtw89_pci rtw89_core 2>/dev/null

echo "正在載入核心預設模組 (modprobe)..."
sudo modprobe rtw89_8922ae

if [ $? -eq 0 ]; then
    echo "✔ 成功載入預設驅動！"
    lsmod | grep rtw89
else
    echo "✘ 載入失敗，請檢查系統是否存有該驅動。"
fi
