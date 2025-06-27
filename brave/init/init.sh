#!/bin/bash

TARGET_DIR="/home/lzc"
TARGET_USER="lzc"
TARGET_GROUP="lzc"

# 获取该目录的实际所有者
OWNER=$(stat -c '%U' "$TARGET_DIR")
DCONF_CONFIG="/home/lzc/.config/dconf/user"

# 如果所有者不是 kasm-user，则更改所有权
if [ "$OWNER" != "$TARGET_USER" ]; then
  echo "Current owner is $OWNER, changing ownership of $TARGET_DIR to $TARGET_USER:$TARGET_GROUP"
  chown -R "$TARGET_USER:$TARGET_GROUP" "$TARGET_DIR"
else
  echo "owner correct, no need to change."
fi

if [ -f "$DCONF_CONFIG" ]; then
  echo "dconf config exists."
else
  echo "dconf config not exists, use default config."
  mkdir -p "$(dirname "$DCONF_CONFIG")"
  cp /lzcapp/pkg/content/dconf_user "$DCONF_CONFIG"
  chown "$TARGET_USER:$TARGET_GROUP" "$DCONF_CONFIG"
fi

