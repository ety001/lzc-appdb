#!/bin/bash
#
# HAOS 网络诊断脚本（方向 B）
# 运行位置：懒猫微服宿主机（root 用户）
# 功能：自动化诊断 QEMU User NAT 下的 mDNS/SSDP 穿透能力
#

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

function ok()   { echo -e "${GREEN}[✓]${NC} $1"; ((PASS++)) || true; }
function err()  { echo -e "${RED}[✗]${NC} $1"; ((FAIL++)) || true; }
function warn() { echo -e "${YELLOW}[!]${NC} $1"; ((WARN++)) || true; }
function info() { echo -e "${BLUE}[i]${NC} $1"; }
function sep()  { echo -e "\n${BLUE}─── $1 ───${NC}\n"; }

# ───────────────────────────────────────────────
#  0. 基础环境检查
# ───────────────────────────────────────────────
sep "0. 环境检查"

HAOS_CONTAINER="inkakawaety001haos-haos-1"

if ! command -v lzc-docker &>/dev/null; then
    err "lzc-docker 命令不存在，请确认在懒猫微服宿主机上运行"
    exit 1
fi

if ! lzc-docker ps --format '{{.Names}}' | grep -q "^${HAOS_CONTAINER}$"; then
    err "HAOS 容器 ${HAOS_CONTAINER} 未运行"
    exit 1
fi
ok "HAOS 容器 ${HAOS_CONTAINER} 运行中"

for cmd in dig nc curl ss grep awk; do
    if command -v "$cmd" &>/dev/null; then
        ok "工具 $cmd 已安装"
    else
        err "工具 $cmd 未安装"
    fi
done

# ───────────────────────────────────────────────
#  1. QEMU 进程与网络配置分析
# ───────────────────────────────────────────────
sep "1. QEMU 网络配置"

QEMU_PID=$(lzc-docker inspect -f '{{.State.Pid}}' "$HAOS_CONTAINER")
QEMU_CMD=$(ps -p "$QEMU_PID" -o args= 2>/dev/null | grep qemu || true)

if [ -z "$QEMU_CMD" ]; then
    err "未找到 QEMU 进程"
else
    ok "QEMU 进程 PID: $QEMU_PID"
    echo "    启动参数摘要:"
    echo "$QEMU_CMD" | grep -o -- '-netdev [^ ]*' | sed 's/^/      /'
    echo "$QEMU_CMD" | grep -o -- 'hostfwd=[^ ]*' | sed 's/^/      /'
fi

# 提取已转发的端口
HOSTFWDS=$(echo "$QEMU_CMD" | grep -oE 'hostfwd=[^,]+' | sed 's/hostfwd=//')
if [ -n "$HOSTFWDS" ]; then
    echo "    当前已转发端口:"
    echo "$HOSTFWDS" | sed 's/^/      /'
    if echo "$HOSTFWDS" | grep -q 'udp.*5353\|5353.*udp'; then
        ok "UDP 5353 (mDNS) 已显式转发"
    else
        warn "UDP 5353 (mDNS) 未在 hostfwd 中显式转发"
    fi
    if echo "$HOSTFWDS" | grep -q 'udp.*1900\|1900.*udp'; then
        ok "UDP 1900 (SSDP) 已显式转发"
    else
        warn "UDP 1900 (SSDP) 未在 hostfwd 中显式转发"
    fi
fi

# 检查宿主机上 QEMU 监听的端口
info "QEMU 在宿主机上监听的端口:"
ss -tlnp | grep "qemu-system-x86" | awk '{print "      " $4 " (PID: " $7 ")"}'

# ───────────────────────────────────────────────
#  2. mDNS 双向穿透测试（自动化部分）
# ───────────────────────────────────────────────
sep "2. mDNS 穿透测试"

info "说明：以下测试在宿主机/容器侧执行，利用 HAOS 内置的 mDNS 服务做验证"

# --- 测试 2A：HAOS mDNS 出站能力（局域网能否"看到"HAOS）---
info "测试 2A：查询 HAOS 是否发布了 _home-assistant._tcp 服务..."

# 在宿主机上执行 dig（因为容器是 host network，和宿主机等效）
MDNS_RESULT=$(dig @224.0.0.251 -p 5353 +short +time=3 +tries=2 PTR _home-assistant._tcp.local 2>/dev/null || true)

if [ -n "$MDNS_RESULT" ]; then
    ok "HAOS mDNS 出站有效！局域网能发现 Home Assistant"
    echo "    查询结果:"
    echo "$MDNS_RESULT" | sed 's/^/      /'
else
    err "HAOS mDNS 出站无效或 HAOS 未发布 _home-assistant._tcp"
    info "可能原因："
    info "  1. QEMU slirp 未转发 multicast 出站"
    info "  2. HAOS 内 systemd-resolved/avahi 未运行"
    info "  3. Home Assistant 尚未初始化完成"
fi

# --- 测试 2B：局域网 mDNS 设备发现（宿主机能否发现局域网设备）---
info "测试 2B：查询局域网内的 _services._dns-sd._udp 记录..."

LAN_MDNS=$(dig @224.0.0.251 -p 5353 +short +time=3 +tries=2 PTR _services._dns-sd._udp.local 2>/dev/null || true)

if [ -n "$LAN_MDNS" ]; then
    ok "宿主机能正常发现局域网 mDNS 设备"
    echo "    发现的服务类型:"
    echo "$LAN_MDNS" | head -5 | sed 's/^/      /'
    if [ "$(echo "$LAN_MDNS" | wc -l)" -gt 5 ]; then
        info "      ... 还有 $(($(echo "$LAN_MDNS" | wc -l) - 5)) 条记录"
    fi
else
    warn "宿主机未在局域网内发现 mDNS 设备（可能局域网内无活跃设备，或 multicast 被路由器阻断）"
fi

# --- 测试 2C：模拟 mDNS 入站（向 224.0.0.251 发查询，看是否有其他设备响应）---
# 这个测试无法直接证明 HAOS 收到了包，只能证明 multicast 在局域网内可传播
info "测试 2C：发送通用 mDNS PTR 查询到局域网..."

GENERIC_MDNS=$(dig @224.0.0.251 -p 5353 +short +time=3 +tries=2 PTR _http._tcp.local 2>/dev/null || true)
if [ -n "$GENERIC_MDNS" ]; then
    ok "局域网内有设备响应了 _http._tcp 查询"
else
    warn "局域网内无 _http._tcp 响应"
fi

# ───────────────────────────────────────────────
#  3. SSDP 穿透测试
# ───────────────────────────────────────────────
sep "3. SSDP 穿透测试"

info "测试 3A：向局域网发送 SSDP M-SEARCH..."

# 发送 SSDP 查询，监听 3 秒响应
SSDP_RESPONSE=$( (
    echo -e 'M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "ssdp:discover"\r\nMX: 2\r\nST: ssdp:all\r\n\r\n'
) | nc -u -w 3 239.255.255.250 1900 2>/dev/null | head -20 || true)

if [ -n "$SSDP_RESPONSE" ]; then
    ok "SSDP 局域网发现有效，收到设备响应"
    echo "    响应摘要:"
    echo "$SSDP_RESPONSE" | grep -E "^ST:|^LOCATION:|^USN:" | head -6 | sed 's/^/      /'
else
    warn "未收到 SSDP 响应（可能局域网无 UPnP 设备，或 multicast 被阻断）"
fi

# ───────────────────────────────────────────────
#  4. 端口连通性与路由测试
# ───────────────────────────────────────────────
sep "4. 端口连通性与路由"

# 测试 8123
curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:8123 >/dev/null 2>&1
if [ $? -eq 0 ]; then
    ok "127.0.0.1:8123 (HA Web) 可访问"
else
    err "127.0.0.1:8123 不可访问"
fi

# 测试 VNC
nc -z -w 2 127.0.0.1 5900 2>/dev/null
if [ $? -eq 0 ]; then
    ok "127.0.0.1:5900 (VNC) 可访问"
else
    err "127.0.0.1:5900 不可访问"
fi

# 测试 HAOS → 宿主机可达性（通过 10.0.2.2）
# 这个测试需要在 HAOS 内执行，脚本无法自动完成
warn "HAOS → 宿主机 (10.0.2.2) 连通性需要手动验证"

# 显示宿主机网络信息
info "宿主机局域网 IP:"
ip -4 addr show enp2s0 2>/dev/null | grep -oP 'inet \K[\d.]+' | sed 's/^/      /' || true

# ───────────────────────────────────────────────
#  5. 生成诊断报告与下一步建议
# ───────────────────────────────────────────────
sep "5. 诊断报告"

echo -e "通过: ${GREEN}${PASS}${NC}  |  失败: ${RED}${FAIL}${NC}  |  警告: ${YELLOW}${WARN}${NC}"
echo ""

# 根据结果给出建议
if [ "$FAIL" -eq 0 ] && [ "$PASS" -ge 4 ]; then
    echo -e "${GREEN}整体评价：网络基础功能正常${NC}"
else
    echo -e "${YELLOW}整体评价：存在需要关注的事项${NC}"
fi

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│                     下一步手动验证清单                       │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""
echo "【必须手动验证】mDNS 入站：HAOS 能否发现局域网设备"
echo "  1. 通过 VNC 或浏览器打开 HAOS: http://192.168.199.52:8123"
echo "  2. 进入 设置 → 系统 → 网络 → 网络诊断（或安装 Terminal Add-on）"
echo "  3. 在 HAOS 内执行:"
echo "       tcpdump -i any -n udp port 5353 -c 10"
echo "  4. 同时，在本脚本运行的宿主机上执行:"
echo "       avahi-publish -s test-device _ssh._tcp 22"
echo "  5. 观察 HAOS 内 tcpdump 是否有来自 192.168.199.x 的 5353 流量"
echo ""
echo "  如果 HAOS 内能抓到包 → mDNS 入站有效，自动发现大概率可用"
echo "  如果抓不到 → mDNS 入站无效，需走 B3 静态配置方案"
echo ""
echo "【建议手动验证】HAOS mDNS 出站：局域网能否发现 HAOS"
echo "  1. 在局域网 Mac/iPhone 上打开 'Bonjour Browser' 或类似 App"
echo "  2. 查找是否能看到 'Home Assistant' 或 '_home-assistant._tcp'"
echo "  3. 如果看不到，说明 mDNS 出站被 slirp 阻断，需部署 B2-1 avahi 代理"
echo ""
echo "【快捷命令】如需扩展 QEMU hostfwd 端口，修改后重启应用:"
echo "  当前 run.sh 中的 QEMU 参数:"
echo "    -netdev user,id=net0,hostfwd=tcp::8123-:8123,hostfwd=tcp::5900-:5900"
echo ""
echo "  建议增加的常用端口:"
echo "    ,hostfwd=tcp::1883-:1883      # MQTT"
echo "    ,hostfwd=udp::5353-:5353       # mDNS (实验性)"
echo "    ,hostfwd=udp::1900-:1900       # SSDP (实验性)"
echo ""

# 如果诊断结果显示 HAOS 出站有效但入站不确定，给出具体建议
if [ -n "$MDNS_RESULT" ] && [ -z "$LAN_MDNS" ]; then
    echo -e "${YELLOW}【特别提示】${NC}"
    echo "  HAOS mDNS 出站有效（局域网能发现 HA），但局域网 mDNS 设备较少。"
    echo "  如果 HAOS 内 tcpdump 确认能收到 multicast，则方向 B 几乎无需大改。"
    echo ""
fi

echo "详细方案参考: PLAN_B_USER_NAT_WORKAROUND.md"
