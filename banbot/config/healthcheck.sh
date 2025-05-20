#!/bin/bash

db_path="/lzcapp/var/pgdata"
pid_path="${db_path}/postmaster.pid"
version_path="${db_path}/PG_VERSION"

# 检查pid文件是否存在
if [ ! -f "$pid_path" ]; then
    exit 1
fi

# 获取文件时间戳
pid_ts=$(stat -c '%Y' "$pid_path")
version_ts=$(stat -c '%Y' "$version_path")

# 比较时间戳并执行相应操作
if [ "$pid_ts" -gt "$version_ts" ]; then
    pg_isready -U postgres -h localhost
    exit $?
else
    exit 1
fi