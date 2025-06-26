#!/bin/bash

TARGET_DIR="/home/lzc"
TARGET_USER="lzc"
TARGET_GROUP="lzc"

# 获取该目录的实际所有者
OWNER=$(stat -c '%U' "$TARGET_DIR")

# 如果所有者不是 kasm-user，则更改所有权
if [ "$OWNER" != "$TARGET_USER" ]; then
  echo "当前所有者为 $OWNER, 修正为 $TARGET_USER:$TARGET_GROUP"
  chown -R "$TARGET_USER:$TARGET_GROUP" "$TARGET_DIR"
else
  echo "所有者正确，无需更改"
fi
