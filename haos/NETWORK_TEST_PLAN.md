# HAOS 网络方案前提条件测试流程

本流程用于验证懒猫微服平台是否具备将 HAOS (QEMU-KVM) 网络从 `user` 模式升级为桥接/反射方案的前提条件。

**测试原则**：按阶段顺序执行，前一阶段不通过则后续阶段无需测试。

---

## 阶段一：容器基础权限与设备检查

**目标**：确认容器是否拥有操作网络所需的内核能力和设备节点。

### 1.1 检查 `/dev/net/tun`
```bash
ls -la /dev/net/tun
```
- **通过**：输出包含 `/dev/net/tun`（字符设备，主设备号 10）
- **不通过**：文件不存在或 `/dev/net/` 目录不存在
- **结论影响**：若**不通过**，则 QEMU `tap`/`bridge` 模式完全不可行，止步于此。

### 1.2 检查 KVM 设备
```bash
ls -la /dev/kvm /dev/vhost-net
```
- **通过**：两者均存在且当前用户有读写权限
- **不通过**：设备不存在或无权限
- **结论影响**：若**不通过**，则 KVM 加速本身异常，需优先解决。

### 1.3 检查 `NET_ADMIN` 能力
```bash
ip link show
capsh --print 2>/dev/null | grep cap_net_admin || cat /proc/self/status | grep Cap
```
- **通过**：能查看宿主机的真实网卡列表（如 `eth0`、`br-lan`、`docker0` 等），且 `cap_net_admin` 在有效集合中
- **不通过**：只能看到 `lo`，或提示权限不足
- **备注**：确保 `lzc-manifest.yml` 中已声明 `netadmin: true`

---

## 阶段二：TAP 设备创建测试

**目标**：验证容器内能否实际创建 TAP 设备。

**前置条件**：阶段一全部通过。

### 2.1 创建 TAP 设备
```bash
ip tuntap add mode tap tap-haos-test
ip link set tap-haos-test up
ip link show tap-haos-test
```
- **通过**：`tap-haos-test` 成功创建并 UP，无权限错误
- **不通过**：`Operation not permitted` 或 `No such file or directory`
- **结论影响**：若**不通过**，QEMU `-netdev tap` 无法使用。

### 2.2 清理测试设备
```bash
ip link del tap-haos-test
```

---

## 阶段三：宿主机网桥可见性与接入测试

**目标**：验证能否将 TAP 设备桥接到宿主机的现有网桥，使虚拟机获得局域网 IP。

**前置条件**：阶段二通过。

### 3.1 查看宿主机网桥
```bash
ip link show type bridge
# 或
brctl show 2>/dev/null || bridge link
```
- **记录**：列出所有网桥名称（如 `br-lan`、`docker0`、`br0`）

### 3.2 尝试将 TAP 加入网桥
```bash
# 假设发现宿主机有 br-lan（替换为实际网桥名）
ip link set tap-haos-test up
ip link set master br-lan dev tap-haos-test
bridge link show tap-haos-test
```
- **通过**：`tap-haos-test` 成功挂到网桥下，无权限错误
- **不通过**：`Operation not permitted` 或 `RTNETLINK answers: No such device`
- **结论影响**：
  - 若**通过**：可走 **QEMU tap + 桥接** 方案，HAOS 能获得局域网 IP，网络完全通透。
  - 若**不通过**：说明平台限制了容器操作宿主机网桥，需退到阶段四的 mDNS 反射方案。

### 3.3 清理测试设备
```bash
ip link del tap-haos-test
```

---

## 阶段四：QEMU Slirp Multicast 穿透测试

**目标**：验证当前 QEMU `user` 模式的 slirp 是否能将多播/广播包转发给 HAOS 虚拟机。

**前置条件**：HAOS 虚拟机正在运行。

### 4.1 在 HAOS 虚拟机内抓包
通过 VNC 或 HAOS Terminal 插件进入系统，执行：
```bash
# 在 HAOS 内（可能需要先安装 tcpdump，或从 Add-on Store 安装 Terminal & SSH）
tcpdump -i any -n udp port 5353
```

### 4.2 在容器侧发送 mDNS 查询
在 HAOS 应用所在的容器里，新开一个 shell：
```bash
# 方法 A：使用 avahi-utils
apt update && apt install -y avahi-utils
avahi-browse -a

# 方法 B：使用 dig
apt install -y dnsutils
dig @224.0.0.251 -p 5353 PTR _services._dns-sd._udp.local

# 方法 C：直接发 UDP 多播包
echo -n "test" | nc -u -b 224.0.0.251 5353
```

### 4.3 观察结果
- **通过**：HAOS 内的 `tcpdump` 能抓到来自 `10.0.2.2` 或容器 IP 的 UDP 5353 包
- **不通过**：HAOS 内无任何 5353 流量
- **结论影响**：
  - 若**通过**：说明 slirp 支持 multicast 转发，可尝试阶段五的 mDNS 反射方案。
  - 若**不通过**：slirp 阻断了 multicast，mDNS 反射器也无法生效，HAOS 只能依赖静态 IP 配置。

---

## 阶段五：mDNS 反射器部署测试（可选）

**目标**：若阶段四通过，验证在容器内运行 mDNS 反射器能否让 HAOS 发现局域网设备。

**前置条件**：阶段四通过。

### 5.1 安装并启动 avahi-reflector
```bash
apt update && apt install -y avahi-daemon
```

写入配置 `/etc/avahi/avahi-daemon.conf`：
```ini
[reflector]
enable-reflector=yes
reflect-ipv=no
```

启动：
```bash
avahi-daemon --no-drop-root
```

### 5.2 在 HAOS 内测试发现
进入 HAOS 的 Terminal，执行：
```bash
avahi-browse -a
# 或查看 Home Assistant 的"集成 -> 添加集成"中是否自动发现了局域网设备
```
- **通过**：HAOS 能发现局域网内的 mDNS 设备（如 `_hap._tcp.`、`_ssh._tcp.` 等）
- **不通过**：无任何发现

### 5.3 备选：mdns-repeater 测试
若 avahi 太重或无效，可测试更轻量的 `mdns-repeater`：
```bash
# 需先编译或找到二进制
mdns-repeater eth0 lo
# 若 HAOS 在 QEMU 内使用固定 IP（如 10.0.2.15），可尝试 socat 定向转发
```

---

## 结论决策树

```
阶段一 (/dev/net/tun + NET_ADMIN)
├── ❌ 不通过 → 无法使用 tap/bridge，保持现有 user NAT 模式
└── ✅ 通过
    └── 阶段二 (创建 TAP)
        ├── ❌ 不通过 → 无法使用 tap/bridge，保持现有 user NAT 模式
        └── ✅ 通过
            └── 阶段三 (桥接接入)
                ├── ✅ 通过 → 推荐方案：QEMU -netdev tap + 宿主机网桥（最佳网络）
                └── ❌ 不通过
                    └── 阶段四 (Slirp multicast)
                        ├── ✅ 通过 → 尝试方案：mDNS 反射器（部分发现能力）
                        └── ❌ 不通过 → 无法改善发现，建议静态 IP 配置集成
```

---

## 附录：快速记录表

| 阶段 | 测试项 | 命令 | 结果 | 备注 |
|------|--------|------|------|------|
| 1.1 | `/dev/net/tun` | `ls -la /dev/net/tun` | ⬜ 通过 / ⬜ 不通过 | |
| 1.2 | KVM 设备 | `ls -la /dev/kvm` | ⬜ 通过 / ⬜ 不通过 | |
| 1.3 | `NET_ADMIN` | `capsh --print` | ⬜ 通过 / ⬜ 不通过 | |
| 2.1 | 创建 TAP | `ip tuntap add mode tap ...` | ⬜ 通过 / ⬜ 不通过 | |
| 3.2 | 桥接接入 | `ip link set master ...` | ⬜ 通过 / ⬜ 不通过 | |
| 4.3 | Slirp multicast | `tcpdump` + `avahi-browse` | ⬜ 通过 / ⬜ 不通过 | |
| 5.2 | mDNS 反射 | `avahi-browse -a` in HAOS | ⬜ 通过 / ⬜ 不通过 | |
