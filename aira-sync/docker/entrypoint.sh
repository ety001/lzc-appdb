#!/bin/sh
# root 启动 → chown 数据目录 → 降权到 node(UID 1000) 运行上游 CMD。
# 替代 lzc-manifest 的 run_as（idmapped 挂载在部分盒子上 EOVERFLOW 失败）。
set -e
if [ "$(id -u)" = "0" ]; then
  chown -R 1000:1000 /data 2>/dev/null || true
  # gosu 不在基础镜像里，用 setpriv（util-linux，bookworm 自带）
  exec setpriv --reuid=1000 --regid=1000 --clear-groups node src/server.js
fi
exec node src/server.js
