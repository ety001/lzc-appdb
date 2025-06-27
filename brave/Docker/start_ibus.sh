#!/bin/bash
# 启动IBus守护进程并设置拼音输入法
set -e

export IBUS_ENABLE_SYNC_MODE=1
export GTK_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export QT_IM_MODULE=ibus
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus

echo "启动IBus守护进程..."
ibus-daemon --xim --replace --verbose --panel=default

echo "等待IBus初始化..."
sleep 3 # 等待2秒确保IBus完全启动

echo "设置拼音输入法为默认..."
ibus engine pinyin

echo "IBus拼音输入法已激活"

# 保持脚本运行，防止Xpra认为进程已退出
tail -f /dev/null