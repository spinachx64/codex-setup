#!/usr/bin/env bash
# 双击本文件即可运行（macOS 会在“终端”中打开）
cd "$(dirname "$0")" || exit 1
# 显式交给系统 Bash 读取，避免 GitHub 下载后脚本执行权限丢失。
/bin/bash ./codex-setup.sh "$@"
STATUS=$?
echo
read -r -p "按回车键关闭窗口..."
exit "$STATUS"
