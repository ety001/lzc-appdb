#!/bin/ash
# Obscura MCP 启动入口：读取 /data/config/obscura.env（挂载自 /lzcapp/var/config）
# 拼装额外启动参数后启动主程序。配置文件修改后重启容器生效。
#
# 配置文件格式（/data/config/obscura.env，KEY=VALUE 每行一个，支持 # 注释）：
#   PROXY=socks5://192.168.1.100:1080      # HTTP 或 SOCKS5 代理，留空/不写 = 直连
#   STEALTH=1                              # 1 = 启用 stealth（反爬指纹 + 广告拦截）
#   USER_AGENT=Mozilla/5.0 ...             # 自定义 UA
#   ALLOW_PRIVATE_NETWORK=1                # 1 = 允许访问内网/回环地址（默认禁止，SSRF 防护）
#
# 注意：. 号引入的环境变量会覆盖容器 environment 的同名变量，配置文件优先级最高。
#
# 0.2.3 起 MCP HTTP 拒绝"非回环绑定且未设 OBSCURA_MCP_TOKEN（>=32 字节）"的
# 实例；lzc 的 mcp.yml 无法给客户端携带 Authorization 头，token 方案走不通。
# 因此主程序绑 127.0.0.1:3001（免 token），由 /relay 把 0.0.0.0:3000 原样
# 转发到回环口，暴露面与 0.2.1 部署一致：仅 lzc 应用网络内可达。
# relay 探测到 obscura 退出后自行退出，容器随 PID1 结束被平台重启拉起。

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

/obscura mcp --http --host 127.0.0.1 --port 3001 $EXTRA &
exec /relay 0.0.0.0:3000 127.0.0.1:3001
