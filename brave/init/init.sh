#!/bin/bash

TARGET_DIR="/home/lzc"
TARGET_USER="lzc"
TARGET_GROUP="lzc"
DCONF_CONFIG="/home/lzc/.config/dconf/user"
XDG_RUNTIME_DIR=/run/user/1001
SSHD_FOLDER="/run/sshd"
XPRA_FOLDER="/run/xpra"

# 获取该目录的实际所有者
OWNER=$(stat -c '%U' "$TARGET_DIR")

# 如果所有者不是 lzc，则更改所有权
if [ "$OWNER" != "$TARGET_USER" ]; then
  echo "Current owner is $OWNER, changing ownership of $TARGET_DIR to $TARGET_USER:$TARGET_GROUP"
  chown -R "$TARGET_USER:$TARGET_GROUP" "$TARGET_DIR"
else
  echo "owner correct, no need to change."
fi

#if [ -f "$DCONF_CONFIG" ]; then
#  echo "dconf config exists."
#else
#  echo "dconf config not exists, use default config."
#  mkdir -p "$(dirname "$DCONF_CONFIG")"
#  cp /lzcapp/pkg/content/dconf_user "$DCONF_CONFIG"
#  chown "$TARGET_USER:$TARGET_GROUP" "$DCONF_CONFIG"
#fi

if [ -d "$XDG_RUNTIME_DIR" ]; then
  echo "XDG_RUNTIME_DIR exists."
else
  echo "XDG_RUNTIME_DIR not exists, create it."
  mkdir -p "$XDG_RUNTIME_DIR"
  chown -R "$TARGET_USER:$TARGET_GROUP" "$XDG_RUNTIME_DIR"
  chmod 0700 "$XDG_RUNTIME_DIR"
fi

if [ -d "$SSHD_FOLDER" ]; then
  echo "sshd folder exists."
else
  echo "sshd folder not exists, create it."
  mkdir -p "$SSHD_FOLDER"
fi

if [ -d "$XPRA_FOLDER" ]; then
  echo "xpra folder exists."
else
  echo "xpra folder not exists, create it."
  mkdir -p "$XPRA_FOLDER"
  chgrp xpra "$XPRA_FOLDER"
  chmod 775 "$XPRA_FOLDER"
fi