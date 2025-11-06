#!/bin/bash

echo "开始初始化..."

# 检查并创建 /etc/crontabs/root 文件
if [ ! -f /etc/crontabs/root ]; then
    echo "创建 /etc/crontabs/root 文件..."
    cat > /etc/crontabs/root << 'EOF'
# do daily/weekly/monthly maintenance
# min   hour    day     month   weekday command
*/15    *       *       *       *       run-parts /etc/periodic/15min
0       *       *       *       *       run-parts /etc/periodic/hourly
0       2       *       *       *       run-parts /etc/periodic/daily
0       3       *       *       6       run-parts /etc/periodic/weekly
0       5       1       *       *       run-parts /etc/periodic/monthly
EOF
fi

# 检查 /etc/periodic 目录是否为空，如果为空则创建子目录
if [ ! -d /etc/periodic ] || [ -z "$(ls -A /etc/periodic 2>/dev/null)" ]; then
    echo "创建 /etc/periodic 目录结构..."
    mkdir -p /etc/periodic/15min
    mkdir -p /etc/periodic/hourly
    mkdir -p /etc/periodic/daily
    mkdir -p /etc/periodic/weekly
    mkdir -p /etc/periodic/monthly
fi

echo "初始化完成，开始启动 supervisor..."
# 启动 supervisor
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
