# aira-sync-admin

Aira Personal Server（`~/workspace/lzc-appdb/aira-sync` 的 LPK）的 Go Web 管理界面。

作为 sidecar 与上游 Node 同步服务共库运行：`/admin` 提供管理页面，其余路径反代到
`AIRA_ADMIN_UPSTREAM`（Node 服务）。LPK 里它是网关域名的唯一入口容器。

## 功能

- **初始配对码（setup-code）展示**：读取 `/data/setup-code` 文件并校验数据库中哈希状态
  （有效 / 已使用 / 已过期 / 不存在），替代 `docker compose exec ... cat /data/setup-code`
- **签发新配对码**：与上游 `POST /v1/pairing/codes` 完全等价——复刻上游
  `createReadableCode()`（18 随机字节 → base64url → 大写，24 字符）与 SHA-256 哈希，
  直接 INSERT `pairing_codes`（kind=device）。TTL 可选 10 分钟～24 小时。原文只显示一次
- **设备管理**：列表（在线状态 = 10 分钟内有活动）、吊销（`UPDATE devices SET revoked_at`，
  与上游 revoke 等价，立即生效于 Node 服务的令牌校验）
- **登录**：`AIRA_ADMIN_TOKEN` 令牌 + HMAC 签名 cookie 会话（12h）

## 安全模型

- 数据库只写 `pairing_codes`（INSERT）和 `devices.revoked_at`（UPDATE），不碰同步数据表
- WAL 模式跨进程并发安全（Node 服务同库），busy_timeout 5s
- 配对码原文与设备令牌均不落库不落日志（与上游一致，只存 SHA-256）
- `/admin` 在 LPK 中保留网关鉴权 + 自身令牌双重校验（注：实测当前 lzcos 的
  `public_path` `!` 排除语法未对 `/admin` 生效，网关层放行，安全完全依赖令牌层）
- 管理界面只在懒猫虚拟网络内可达（heiyu.space 域名不对外解析）

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `AIRA_ADMIN_LISTEN` | `0.0.0.0:8080` | 监听地址 |
| `AIRA_ADMIN_DB` | `/data/aira-personal-server.db` | SQLite 路径 |
| `AIRA_ADMIN_SETUP_CODE` | `/data/setup-code` | 初始配对码文件 |
| `AIRA_ADMIN_UPSTREAM` | `http://aira-server:8787` | Node 同步服务地址 |
| `AIRA_ADMIN_TOKEN` | 无（**必填**） | 管理令牌。未设置时进程直接退出（fail-fast），由懒猫引导页部署参数注入，不做自动生成 |

## 构建

```bash
CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o aira-sync-admin .
# Docker（LPK 用的镜像）
docker buildx build --builder ssd --platform linux/amd64 \
  -t ety001/aira-personal-server:admin-$(date +%Y%m%d)-N -f docker/Dockerfile --push .
lzc-cli appstore copy-image ety001/aira-personal-server:admin-...
```

纯 Go（modernc.org/sqlite），无 CGO，静态二进制约 21MB。

## 本地集成测试

```bash
# 起 Node 服务 + admin
AIRA_DATA_DIR=/tmp/aira-test-data AIRA_PORT=18787 node ~/workspace/aira-browser/services/personal-server/src/server.js &
AIRA_ADMIN_DB=/tmp/aira-test-data/aira-personal-server.db \
AIRA_ADMIN_SETUP_CODE=/tmp/aira-test-data/setup-code \
AIRA_ADMIN_UPSTREAM=http://127.0.0.1:18787 \
AIRA_ADMIN_LISTEN=127.0.0.1:19099 AIRA_ADMIN_TOKEN=test ./aira-sync-admin &
# UI 签发的码可以直接在 Node 端配对（已验证）
```

## 踩坑记录（Go 侧）

1. **ServeMux method pattern 陷阱**：`mux.HandleFunc("GET /", ...)` 会让所有 POST 落到
   Go 内置 405（Method Not Allowed），同步客户端全部用 POST——根路由必须写 `"/"` 不带方法
2. **上游配对码格式**：必须逐字节复刻 `crypto.randomBytes(18).toString('base64url').toUpperCase()`，
   哈希用 SHA-256 hex；格式不对 Node 端拒绝（invalid_pairing_code）
3. **better-sqlite3 WAL + Go modernc sqlite 共存**：Go 侧连接串加
   `?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)`，`SetMaxOpenConns(1)` 串行化写
