#!/usr/bin/env bash
# 双击本文件即可运行（macOS 会在“终端”中打开）
cd "$(dirname "$0")" || exit 1
./codex-setup.sh
STATUS=$?
echo
read -r -p "按回车键关闭窗口..."
exit "$STATUS"
