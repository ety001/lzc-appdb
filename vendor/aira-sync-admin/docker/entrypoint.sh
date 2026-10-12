#!/bin/sh
# root 启动 → chown 数据目录 → setpriv 降权到 UID 1000（与 aira-server 的 node 用户一致，
# 两个容器共写 /data 的 SQLite WAL）。
# 替代镜像 USER / manifest run_as（idmapped 挂载在部分盒子上 EOVERFLOW 失败）。
set -e
if [ "$(id -u)" = "0" ]; then
  chown -R 1000:1000 /data 2>/dev/null || true
  exec setpriv --reuid=1000 --regid=1000 --clear-groups aira-sync-admin
fi
exec aira-sync-admin
