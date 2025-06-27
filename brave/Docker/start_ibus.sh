#!/bin/bash
# 启动IBus守护进程并设置拼音输入法
set -e

echo "启动IBus守护进程..."
ibus-daemon --xim --replace --verbose

echo "等待IBus初始化..."
sleep 2  # 等待2秒确保IBus完全启动

echo "设置拼音输入法为默认..."
ibus engine pinyin

echo "IBus拼音输入法已激活"

# 保持脚本运行，防止Xpra认为进程已退出
tail -f /dev/null