#!/bin/bash

# --- 配置 ---
QUOTE_FILE="$HOME/.config/hyprlock-script/quote.txt"
FALLBACK_QUOTE="私は虚無の先  筆の限界"

# ----------------------------------------------------QUOTE_FILE

if [ -f "$QUOTE_FILE" ]; then
    # 使用 shuf (或 gshuf) 从本地文件中随机抽取一行
    QUOTE=$(shuf -n 1 "$QUOTE_FILE")
    
    if [ -z "$QUOTE" ]; then
        # 如果文件存在但为空
        echo "$FALLBACK_QUOTE"
    else
        echo "$QUOTE"
    fi
else
    # 本地文件不存在
    echo "$FALLBACK_QUOTE"
fi
