# Aira Sync（Aira 浏览器私有化同步服务器）

将 [Aira 浏览器](https://github.com/mason173/aira-browser) 官方 `services/personal-server` 移植为懒猫微服 LPK 应用。

## 这是什么

单用户私有化同步服务器：手机 Aira App 与电脑 Aira-sync 浏览器扩展配对到同一台服务器后，可同步书签、历史记录、个性化设置、小说书架，并使用网页接力（Page Push）与跨设备标签页。无需华为账号或 Aira Pro。

v0.4.0 起内置 **Web 管理界面**（Go sidecar，`https://aira-sync.<box>.heiyu.space/admin`）：查看初始配对码、一键签发新配对码、设备列表与吊销——不用再 SSH 到盒子。

- 上游源码: https://github.com/mason173/aira-browser (`services/personal-server`)
- 上游版本: 0.3.0 @ commit `f6fcbc6`
- 镜像: `ety001/aira-personal-server:upstream-f6fcbc6` (Docker Hub) → `registry.lazycat.cloud/ety001/ety001/aira-personal-server:7c51f9167cdd7865`
- 管理界面源码: `vendor/aira-sync-admin/`（本仓库内，Go，GPL-3.0），镜像 `...aira-personal-server:1a56b9b0cc93f82c`
- License: GPL-3.0-only（源码）；名称使用符合上游 TRADEMARKS.md（"based on Aira Personal Server"）

## 部署形态

| 访问方式 | 地址 | 说明 |
|---|---|---|
| 懒猫网关域名 | `https://aira-sync.<box>.heiyu.space` | Go sidecar 入口：`/admin` 管理界面，其余反代同步 API（public_path `/`，Aira 自身鉴权） |
| 管理界面 | `https://aira-sync.<box>.heiyu.space/admin` | 令牌登录（安装参数 `admin_token`，不填则启动随机生成，`lzc-docker logs` 查看） |
| 四层直连 | `http://aira-sync.<box>.heiyu.space:8787` | TCP ingress 直达 Node 服务，绕过网关体限制，懒猫虚拟网络内可达 |

`AIRA_PUBLIC_URL` 通过可选部署参数 `public_url` 注入，默认留空（各设备以自己填写的地址为准：手机端忽略 discovery 的 baseUrl，扩展端空值时回退到用户输入地址）。

## 使用步骤

1. 打开 `https://aira-sync.<box>.heiyu.space/admin`，输入管理令牌登录
   （未设置 `admin_token` 参数时，SSH 执行
   `ssh root@<box-ip> "/lzcsys/bin/lzc-docker logs inkakawaety001aira-sync-aira-admin-1 2>&1 | grep 'admin token'"`
   查看随机生成的令牌）
2. 首页直接显示**初始配对码**（24 小时有效，仅第一台设备；被使用后此卡片自动转为引导签发新码）
3. 手机: Aira → 设置 → 同步 → 私有化部署，填 `https://aira-sync.<box>.heiyu.space` + 配对码
4. 电脑: 安装 Aira-sync 扩展（Chrome/Edge/Firefox 商店，或 GitHub Releases 的 Community 包）→ 连接私有化部署 → 填同一地址
5. 之后每台新设备：管理界面点「生成配对码」（TTL 可选 10 分钟～24 小时，一次性使用）→ 在新设备配对页填入。解决了上游客户端没有"生成配对码"入口的问题
6. 手机端打开 设置 → 与电脑互联。设备丢失/退役：管理界面「吊销」立即失效其令牌

## 数据与备份

- 数据库: `/lzcapp/var/data/aira-personal-server.db`（宿主机 `/lzcsys/data/appvar/ink.akawa.ety001.aira-sync/data/`）
- 在线备份: `lzc-docker exec <容器> npm run backup -- /data/aira.backup`
- 同步 ≠ 备份，请另行保留备份。

## 移植要点（坑）

1. **`run_as: "1000:1000"` 必须声明**: 上游容器以 `node` 用户（UID 1000）运行且数据在 `/data`。不声明 run_as 时 `/lzcapp/var/data` 归 root，better-sqlite3 报 `SQLITE_CANTOPEN` 退出。
2. **`public_path: /`**: 手机 App / 扩展的请求不带懒猫网关登录态，会被 307 到登录页。Aira 自带一次性配对码 + 设备 Bearer 令牌鉴权（服务端只存 SHA-256 哈希），未认证可达端点仅 `/health`、`/.well-known/aira`、`/v1/pairing/exchange`（需有效配对码）。
3. **可选部署参数的 `<no value>` 坑**: 未填写的可选参数渲染成字面量 `<no value>`。`AIRA_PUBLIC_URL={{ .U.public_url | default "" }}` 必须加 `default ""`，否则 discovery 返回的 baseUrl 是 `<no value>` 字符串，扩展端 normalizeBaseUrl 抛 `invalid_personal_server_url`。
4. **网关请求体限制**: 网关域名走 routes 有体限制，书签全量快照（上限 12 MiB）可能被网关拦截；TCP ingress 直连 8787 无此限制。日常同步增量很小，网关域名一般够用。
5. **更新应用不触发 ingress 重新注册**: 改 ingress 配置后要卸载重装（uninstall + install），不是覆盖安装。
6. **服务名不能用 `app`**: service 名 `aira-server`。
7. **upstreams 的 location 路径分流只有精确匹配生效**: `location: /admin` 只命中精确的 `/admin`，`/admin/login` 等子路径仍落到 `routes /`（文档语义与实测不符）。要在同一域名下分流路径，让一个容器自己分流（Go sidecar 内部路由），别指望 ingress。
8. **domain_prefix 前缀域名 + 网关鉴权 = API/CLI 404**: `<prefix>-<subdomain>.<box>.heiyu.space` 域名在需要网关鉴权时，Lzc-Api-Auth-Token 身份会得到 404 "Unable to retrieve corresponding service information"（gogs 等普通子域名同 token 正常 200）。multica 的 api- 域名能用是因为它 public_path 全开不走鉴权路径。浏览器 cookie 是否正常未验证。
9. **binds 不支持 `:ro` 后缀**: `invalid bind: /lzcapp/var/data:/data:ro`，读写都写裸路径，权限靠 UID 对齐（run_as）。
10. **public_path 的 `!` 排除语法实测未生效**: `!/admin/*` 写法构建/安装不报错，但网关层并未对 `/admin` 恢复鉴权（未带登录态访问直达后端）。安全边界要按"public_path 排除不生效"来设计（本应用靠管理令牌层兜底）。
11. **Go sidecar 反代必须转发所有方法**: `mux.HandleFunc("GET /", ...)` 的 Go 1.22 method pattern 会把 POST 落到内置 405。同步 API 全是 POST，根路由 pattern 写 `"/"` 不带方法。

## 重建流程

```bash
# 1. 源码在 ~/workspace/aira-browser (git clone https://github.com/mason173/aira-browser)
cd ~/workspace/aira-browser && git pull
commit_id="upstream-$(git rev-parse --short HEAD)"

# 2. 构建 + 推送镜像（仅 amd64）
docker buildx build --builder ssd --platform linux/amd64 \
  -t ety001/aira-personal-server:${commit_id} \
  -f ~/workspace/lzc-appdb/aira-sync/docker/Dockerfile \
  --push ~/workspace/aira-browser/services/personal-server

# 3. 同步到懒猫 registry
lzc-cli appstore copy-image ety001/aira-personal-server:${commit_id}

# 4. 更新 lzc-manifest.yml 的 image，重建 LPK
cd ~/workspace/lzc-appdb/aira-sync && lzc-cli project build

# 5. 安装（远程模式 lzc-cli app install 失败时用 lpk-manager）
scp ink.akawa.ety001.aira-sync-*.lpk root@<box-ip>:/tmp/
ssh root@<box-ip> "/lzcsys/bin/lpk-manager install /tmp/ink.akawa.ety001.aira-sync-*.lpk"
# 注意: 改过 ingress 就要 uninstall + install

# 6. 回归验证
curl -sk https://aira-sync.<box>.heiyu.space/health
curl -sk https://aira-sync.<box>.heiyu.space/.well-known/aira   # baseUrl 应为 ""
docker run --rm ety001/aira-personal-server:${commit_id} npm run check
```

## 安全说明

- 服务器管理员可读取同步数据（上游 SECURITY.md：无端到端加密）。
- 两个入口都只在懒猫虚拟网络内可达；不要把 8787 暴露到不受信任网络。
- 断开连接只移除设备连接，不删除设备上已有浏览数据。
