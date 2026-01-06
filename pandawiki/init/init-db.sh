#!/bin/bash
set -e

# 等待 PostgreSQL 启动
echo "Waiting for PostgreSQL to start..."
until pg_isready -h postgres -U panda-wiki; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done

echo "PostgreSQL is up - creating raglite database"

# 创建 raglite 数据库
PGPASSWORD=pandawiki123 psql -h postgres -U panda-wiki -d panda-wiki -c "CREATE DATABASE raglite;" || echo "Database raglite may already exist"

echo "Database initialization completed"
