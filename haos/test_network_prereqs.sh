#!/bin/bash
#
# HAOS 网络方案前提条件测试脚本
# 运行环境：HAOS 应用所在的 Docker 容器内
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

function check_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASS++)) || true
}

function check_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAIL++)) || true
}

function check_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function section() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

# ==================== 阶段一 ====================
section "阶段一：容器基础权限与设备检查"

echo ""
echo "--- 1.1 检查 /dev/net/tun ---"
if [ -c /dev/net/tun ]; then
    ls -la /dev/net/tun
    check_pass "/dev/net/tun 存在且为字符设备"
else
    check_fail "/dev/net/tun 不存在"
fi

echo ""
echo "--- 1.2 检查 /dev/kvm 和 /dev/vhost-net ---"
KVM_OK=true
for dev in /dev/kvm /dev/vhost-net; do
    if [ -e "$dev" ]; then
        ls -la "$dev"
        check_pass "$dev 存在"
    else
        check_fail "$dev 不存在"
        KVM_OK=false
    fi
done

echo ""
echo "--- 1.3 检查 NET_ADMIN 能力和宿主机网卡可见性 ---"
# 尝试查看非 lo 的网卡
NON_LO_IFACES=$(ip -o link show | grep -v "lo:" | wc -l)
if [ "$NON_LO_IFACES" -gt 0 ]; then
    echo "容器可见的网卡列表："
    ip -o link show | awk -F': ' '{print $2}' | grep -v "^lo$" | sed 's/^/  - /'
    check_pass "能看到宿主机网卡（network_mode=host 生效）"
else
    check_fail "只能看到 lo，宿主机网卡不可见"
fi

# 检查 cap_net_admin
if command -v capsh &>/dev/null; then
    if capsh --print | grep -q "cap_net_admin"; then
        check_pass "cap_net_admin 在能力集中"
    else
        check_warn "capsh 未显示 cap_net_admin（可能以其他形式存在）"
    fi
else
    check_warn "capsh 未安装，尝试通过 /proc/self/status 判断"
    if [ -f /proc/self/status ]; then
        CAPS=$(grep CapEff /proc/self/status | awk '{print $2}')
        echo "当前 CapEff: $CAPS"
        # 0x10000000 = 28th bit = CAP_NET_ADMIN
        # 简单判断：如果 CapEff 不是 0，至少有一些能力
        if [ "$CAPS" != "0000000000000000" ]; then
            check_pass "容器拥有非空 capability 集合"
        else
            check_fail "容器 capability 为空"
        fi
    fi
fi

# ==================== 阶段二 ====================
section "阶段二：TAP 设备创建测试"

if [ ! -c /dev/net/tun ]; then
    check_fail "跳过：/dev/net/tun 不存在，无法创建 TAP"
else
    echo ""
    echo "--- 2.1 尝试创建 TAP 设备 tap-haos-test ---"
    if ip tuntap add mode tap tap-haos-test 2>/dev/null; then
        ip link set tap-haos-test up
        if ip link show tap-haos-test &>/dev/null; then
            check_pass "成功创建并启动 tap-haos-test"
        else
            check_fail "创建后无法查看设备"
        fi

        echo ""
        echo "--- 2.2 清理测试设备 ---"
        ip link del tap-haos-test 2>/dev/null || true
        check_pass "已清理 tap-haos-test"
    else
        check_fail "无法创建 TAP 设备（ip tuntap add 失败）"
    fi
fi

# ==================== 阶段三 ====================
section "阶段三：宿主机网桥可见性与接入测试"

if ! ip tuntap add mode tap tap-haos-test 2>/dev/null; then
    check_fail "跳过：无法创建 TAP，阶段三无需测试"
else
    ip link set tap-haos-test up 2>/dev/null || true

    echo ""
    echo "--- 3.1 查看宿主机网桥 ---"
    BRIDGES=$(ip -o link show type bridge 2>/dev/null | awk -F': ' '{print $2}' || true)
    if [ -n "$BRIDGES" ]; then
        echo "发现的网桥："
        echo "$BRIDGES" | sed 's/^/  - /'
        check_pass "宿主机存在可用网桥"

        # 尝试加入第一个网桥
        FIRST_BRIDGE=$(echo "$BRIDGES" | head -n1)
        echo ""
        echo "--- 3.2 尝试将 TAP 加入网桥 $FIRST_BRIDGE ---"
        if ip link set master "$FIRST_BRIDGE" dev tap-haos-test 2>/dev/null; then
            check_pass "成功将 TAP 加入网桥 $FIRST_BRIDGE"
        else
            check_fail "无法将 TAP 加入网桥（权限或平台限制）"
        fi
    else
        check_warn "未发现宿主机网桥（bridge link 为空）"
        check_fail "无可用网桥，桥接方案不可行"
    fi

    echo ""
    echo "--- 3.3 清理测试设备 ---"
    ip link del tap-haos-test 2>/dev/null || true
fi

# ==================== 阶段四 ====================
section "阶段四：QEMU Slirp Multicast 穿透测试"

echo ""
echo "--- 4.1 环境准备检查 ---"
if command -v avahi-browse &>/dev/null; then
    check_pass "avahi-browse 已安装"
    HAVE_AVAHI=true
else
    check_warn "avahi-browse 未安装，阶段五将需要手动安装"
    HAVE_AVAHI=false
fi

if command -v dig &>/dev/null; then
    check_pass "dig 已安装"
    HAVE_DIG=true
else
    check_warn "dig 未安装，可用 nc 替代发测试包"
    HAVE_DIG=false
fi

echo ""
echo "--- 4.2 QEMU 网络信息 ---"
echo "当前容器 IP 路由："
ip route | sed 's/^/  /'
echo ""
echo "监听中的 UDP/5353 进程（如果 HAOS 在运行且 slirp 转发，可能看不到）："
ss -ulnp 2>/dev/null | grep 5353 || echo "  无进程监听 5353"

echo ""
echo "--- 4.3 发送测试 mDNS 查询包 ---"
echo "请在 HAOS 虚拟机内执行：tcpdump -i any -n udp port 5353"
echo "然后按回车继续发送测试包..."
read -r

if [ "$HAVE_DIG" = true ]; then
    echo "执行: dig @224.0.0.251 -p 5353 PTR _services._dns-sd._udp.local"
    dig @224.0.0.251 -p 5353 PTR _services._dns-sd._udp.local +short +time=2 +tries=1 || true
else
    echo "执行: echo test | nc -u -b 224.0.0.251 5353 -w 2"
    echo "test-mdns-$(date +%s)" | nc -u -b 224.0.0.251 5353 -w 2 || true
fi

echo ""
echo "请检查 HAOS 内的 tcpdump 输出，然后在此输入结果 [y/N]:"
read -r HAOS_RESULT
if [[ "$HAOS_RESULT" =~ ^[Yy]$ ]]; then
    check_pass "HAOS 收到了 multicast 包（Slirp 支持 multicast 转发）"
else
    check_fail "HAOS 未收到 multicast 包（Slirp 可能阻断了 multicast）"
fi

# ==================== 汇总 ====================
section "测试结果汇总"
echo -e "通过: ${GREEN}$PASS${NC} 项"
echo -e "失败: ${RED}$FAIL${NC} 项"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}所有前置条件均已满足！${NC}"
    echo "推荐方案："
    echo "  1. 首选：QEMU -netdev tap + 宿主机网桥桥接"
    echo "  2. 备选：保持 user NAT + avahi-reflector mDNS 反射"
else
    echo -e "${YELLOW}部分条件不满足，请根据上方 FAIL 项参考决策树选择方案。${NC}"
fi

echo ""
echo "详细决策参考：NETWORK_TEST_PLAN.md"
