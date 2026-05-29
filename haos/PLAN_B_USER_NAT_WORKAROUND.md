# 方向 B 计划：User NAT 下的网络发现增强方案

## 一、现状确认

HAOS 虚拟机运行在 QEMU User Mode NAT (slirp) 中：
- Guest IP: `10.0.2.15/24`
- Gateway/DNS: `10.0.2.2/10.0.2.3`
- 宿主机: `192.168.199.52` (局域网)
- 已转发端口: `8123` (Web)、`5900` (VNC)
- 容器权限: `host network`，但**无** `/dev/net/tun` 和 `NET_ADMIN`

**核心限制**：虚拟机躲在 NAT 后面，多播/广播的双向穿透能力存疑。

---

## 二、第一阶段：诊断（明确哪些协议能工作）

### 2.1 测试 mDNS 双向穿透

**目标**：验证 QEMU slirp 是否支持 multicast UDP 在 guest 和局域网之间的双向转发。

#### 步骤 A：HAOS 能否"听到"局域网的 mDNS

在**宿主机**上发布一个测试 mDNS 服务：
```bash
# 宿主机执行
apt install -y avahi-utils 2>/dev/null || true
avahi-publish -s "test-host" _ssh._tcp 22 "test=yes" &
```

在 **HAOS 虚拟机内**（通过 VNC 或 Terminal Add-on）抓包：
```bash
# HAOS 内执行（先安装 tcpdump 或通过 Portainer/Terminal 执行）
tcpdump -i any -n udp port 5353 -c 10
```

同时，在**容器内**发送 mDNS 查询：
```bash
# 进入 HAOS 容器
lzc-docker exec -it inkakawaety001haos-haos-1 sh

# 安装 dig 或 nc
apt update && apt install -y dnsutils

# 发送 mDNS PTR 查询
dig @224.0.0.251 -p 5353 PTR _ssh._tcp.local +short
```

**判断**：
- ✅ 如果 HAOS 内 `tcpdump` 能抓到来自 `192.168.199.x` 或 `10.0.2.2` 的 5353 包 → **mDNS 入站有效**
- ❌ 如果 HAOS 内完全无流量 → **slirp 未转发 multicast 入站**

#### 步骤 B：HAOS 的 mDNS 能否"传到"局域网

在**局域网其他设备**（如 Mac、Linux PC、iPhone 的 Discovery App）上浏览 mDNS 服务。

在 **HAOS 内**开启 Home Assistant 的某个自带 mDNS 的集成（如 `cast`、`homekit`），或者手动发布：
```bash
# HAOS 内（如果 avahi-daemon 可用）
avahi-publish -s "haos-test" _http._tcp 8123
```

**判断**：
- ✅ 如果局域网设备能看到 `haos-test` → **mDNS 出站有效**
- ❌ 如果看不到 → **slirp 未转发 multicast 出站（或 NAT 导致源 IP 不可达）**

#### 步骤 C：SSDP 测试

类似 mDNS，测试 SSDP (239.255.255.250:1900)：
```bash
# 容器内发送 SSDP M-SEARCH
echo -e 'M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "ssdp:discover"\r\nMX: 3\r\nST: ssdp:all\r\n\r\n' | nc -u -w 3 239.255.255.250 1900
```

在 HAOS 内抓包 `udp port 1900`。

---

## 三、第二阶段：根据诊断结果选择 Workaround

### 场景一：mDNS 入站有效（HAOS 能发现局域网设备）

这是最幸运的情况。意味着：
- HAOS 发 mDNS 查询 → 局域网设备收到 → 响应 multicast → slirp 转发回 HAOS

**方案**：无需额外操作，Home Assistant 的自动发现（`discovery`、`zeroconf` 集成）大概率能正常工作。

**验证**：在 Home Assistant 中查看 设置 → 设备与服务 → 已发现，看是否有新设备自动出现。

---

### 场景二：mDNS 入站无效，但出站有效（HAOS 能被局域网发现，但发现不了别人）

**方案 B2-1：宿主机侧 mDNS 代理发布**

在**容器/宿主机**上运行 avahi-daemon，**代表 HAOS 向局域网发布服务记录**，指向宿主机的 IP（即 HAOS 的访问入口）。

```bash
# 在 HAOS 容器内运行
apt update && apt install -y avahi-daemon
```

创建服务描述文件 `/etc/avahi/services/haos.service`：
```xml
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">Home Assistant on %h</name>
  <service>
    <type>_home-assistant._tcp</type>
    <port>8123</port>
    <txt-record>base_url=http://192.168.199.52:8123</txt-record>
    <txt-record>version=2024.x</txt-record>
    <txt-record>requires_auth=true</txt-record>
  </service>
  <!-- 如需模拟 HomeKit Bridge -->
  <service>
    <type>_hap._tcp</type>
    <port>8123</port>
    <txt-record>md=Home Assistant Bridge</txt-record>
    <txt-record>pv=1.1</txt-record>
    <txt-record>id=AA:BB:CC:DD:EE:FF</txt-record>
    <txt-record>c#=1</txt-record>
    <txt-record>s#=1</txt-record>
    <txt-record>ff=0</txt-record>
    <txt-record>ci=2</txt-record>
    <txt-record>sf=1</txt-record>
    <txt-record>sh=abcdefghij==</txt-record>
  </service>
</service-group>
```

启动 avahi：
```bash
avahi-daemon --no-drop-root
```

**效果**：局域网内的 iPhone/Mac/Apple TV 会通过 mDNS "发现" Home Assistant，实际连接时走 `192.168.199.52:8123` → 宿主机 → slirp NAT → HAOS。

**局限**：
- 只能解决"HAOS 被局域网发现"的问题
- HAOS 主动发现局域网设备（如小米网关、Chromecast）仍然受限
- HomeKit 的配对码需要在 HAOS 和代理文件之间手动同步

---

### 场景三：mDNS 双向均无效（最可能的情况）

**方案 B3：扩展端口转发 + HAOS 内静态配置**

#### 3.1 扩展 QEMU hostfwd 端口

HAOS 及周边生态常用的端口：
| 端口 | 协议 | 用途 |
|------|------|------|
| 1883 | TCP | MQTT（如果 HAOS 内跑 MQTT broker） |
| 8883 | TCP | MQTT over TLS |
| 5353 | UDP | mDNS（即使 slirp 不支持，也试试显式转发） |
| 1900 | UDP | SSDP/UPnP |
| 5683 | UDP | CoAP |
| 1400 | TCP | Sonos |
| 32400 | TCP | Plex（如果跑在 HAOS Add-on 里） |

修改 `init/run.sh` 或 `docker/run.sh` 中的 QEMU 启动参数：
```bash
-netdev user,id=net0,\
  hostfwd=tcp::8123-:8123,\
  hostfwd=tcp::5900-:5900,\
  hostfwd=tcp::1883-:1883,\
  hostfwd=tcp::5353-:5353,\
  hostfwd=udp::5353-:5353,\
  hostfwd=udp::1900-:1900
```

**注意**：`hostfwd=udp::5353-:5353` 对 multicast 可能无效，但值得一试。

#### 3.2 HAOS 内使用宿主机的局域网服务

HAOS 虚拟机可以通过 `10.0.2.2` 访问宿主机。如果局域网内有 MQTT Broker、NAS 等，在 HAOS 配置中填 `10.0.2.2` 即可通过宿主机中转访问。

示例：MQTT 集成配置
- Broker: `10.0.2.2`
- Port: `1883`
- 如果 MQTT 跑在宿主机的其他容器里，确保该容器也监听了宿主机的 `0.0.0.0:1883`

#### 3.3 常用集成的静态配置指南

| 集成 | 发现依赖 | 静态配置方式 |
|------|----------|--------------|
| Xiaomi Miot Auto | mDNS/局域网扫描 | 在 HACS 安装后，手动输入设备 IP |
| ESPHome | mDNS | 在 `configuration.yaml` 中直接写 `api:` 和 IP |
| Google Cast | mDNS | 无法完全绕过，可尝试填具体 Chromecast IP |
| Apple HomeKit Bridge | mDNS (_hap._tcp) | 用方案 B2-1 的 avahi 代理发布 |
| Sonos | SSDP | 手动输入 Sonos 音箱 IP |
| Shelly | mDNS/CoIoT | 手动添加集成并输入 IP |
| Tasmota | mDNS | 手动输入 IP 或配置 MQTT |

---

### 场景四：特定协议需要宿主机代理

**方案 B4：宿主机侧协议代理**

对于某些必须在局域网"对等"通信的协议，可以在宿主机/容器内运行代理：

#### B4-1：MQTT Broker 桥接
如果 HAOS 内的设备（如 Zigbee2MQTT）需要被局域网外的设备订阅：
- 在宿主机跑一个公共 MQTT Broker（如 Mosquitto）
- HAOS 内的 Zigbee2MQTT 连接 `10.0.2.2:1883`
- 局域网设备连接 `192.168.199.52:1883`
- 两者实际是同一个 Broker

#### B4-2：DLNA/UPnP 代理
对于媒体服务器（如 HAOS 内的 Plex/Jellyfin Add-on）：
- DLNA 严重依赖 SSDP multicast，在 NAT 下基本不可用
- **替代方案**：不用 DLNA，直接用 Plex/Jellyfin 的 Web 界面或客户端直连 `192.168.199.52:8123`

---

## 四、第三阶段：长期架构优化（可选）

### 4.1 在 manifest 中申请更多权限（回到方向 A 的轻量版）

虽然当前平台不给 `/dev/net/tun`，但可以在后续版本尝试：

```yaml
# lzc-manifest.yml
services:
  haos:
    netadmin: true
    # 尝试添加设备映射（不确定平台是否支持）
```

然后向懒猫团队反馈：KVM 场景下需要 `/dev/net/tun` 设备支持。

### 4.2 使用 QEMU 的 `-netdev socket` 做外部桥接

如果平台以后支持 IPC/socket 方式传递网络后端，可以让 QEMU 使用宿主机上预先创建的 TAP：
```bash
# 宿主机侧（需要 root 权限）
ip tuntap add mode tap tap-haos
qemu-system-x86_64 ... -netdev socket,id=net0,fd=3 -device virtio-net-pci,netdev=net0
```
但这需要 manifest 支持传递已打开的文件描述符，当前平台几乎不可能支持。

---

## 五、执行优先级建议

```
立即执行（今天）：
  └─ 2.1 诊断（mDNS/SSDP 双向测试）

本周执行：
  ├─ 如果 mDNS 入站有效 → 验证 HA 自动发现，可能无需改动
  ├─ 如果 mDNS 出站有效 → 部署方案 B2-1（avahi 代理发布）
  └─ 如果双向均无效 → 扩展 hostfwd 端口 + 静态配置常用集成

后续优化：
  └─ 向懒猫团队反馈：KVM 应用需要 /dev/net/tun 支持
```

---

## 六、验证清单

| 检查项 | 命令/方法 | 预期结果 |
|--------|-----------|----------|
| mDNS 入站 | HAOS 内 `tcpdump -i any udp port 5353` | 能看到局域网设备响应 |
| mDNS 出站 | 局域网设备 `avahi-browse -a` | 能看到 HAOS 发布的服务 |
| SSDP 入站 | HAOS 内 `tcpdump udp port 1900` | 能看到 SSDP 广播 |
| 宿主机可达 | HAOS 内 `ping 10.0.2.2` | 能通 |
| 外网可达 | HAOS 内 `ping 8.8.8.8` | 能通 |
| 端口转发 | `curl http://192.168.199.52:8123` | 返回 HA 登录页 |
