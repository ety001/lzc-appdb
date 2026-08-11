#!/bin/ash
# Obscura MCP 启动入口：读取 /data/config/obscura.env（挂载自 /lzcapp/var/config）
# 拼装额外启动参数后 exec 主程序。配置文件修改后重启容器生效。
#
# 配置文件格式（/data/config/obscura.env，KEY=VALUE 每行一个，支持 # 注释）：
#   PROXY=socks5://192.168.1.100:1080      # HTTP 或 SOCKS5 代理，留空/不写 = 直连
#   STEALTH=1                              # 1 = 启用 stealth（反爬指纹 + 广告拦截）
#   USER_AGENT=Mozilla/5.0 ...             # 自定义 UA
#   ALLOW_PRIVATE_NETWORK=1                # 1 = 允许访问内网/回环地址（默认禁止，SSRF 防护）
#
# 注意：. 号引入的环境变量会覆盖容器 environment 的同名变量，配置文件优先级最高。

CONFIG_DIR="${CONFIG_DIR:-/data/config}"
ENV_FILE="$CONFIG_DIR/obscura.env"

EXTRA=""
if [ -f "$ENV_FILE" ]; then
    . "$ENV_FILE" 2>/dev/null || true
fi

if [ -n "${PROXY:-}" ]; then
    EXTRA="$EXTRA --proxy $PROXY"
fi
if [ "${STEALTH:-0}" = "1" ]; then
    EXTRA="$EXTRA --stealth"
fi
if [ -n "${USER_AGENT:-}" ]; then
    EXTRA="$EXTRA --user-agent $USER_AGENT"
fi
if [ "${ALLOW_PRIVATE_NETWORK:-0}" = "1" ]; then
    EXTRA="$EXTRA --allow-private-network"
fi

exec /obscura mcp --http --host 0.0.0.0 --port 3000 $EXTRA
