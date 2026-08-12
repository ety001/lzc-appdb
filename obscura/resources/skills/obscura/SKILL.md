---
name: obscura
description: 当用户要求搜索网页、查看网页内容、打开/访问/测试链接、提取页面正文、将页面转为 Markdown、查看页面链接列表、点击页面元素、填写表单、模拟键盘/鼠标操作、滚动页面、执行页面 JavaScript、获取浏览器控制台消息或网络请求、获取页面截图或 PDF、管理浏览器标签页时使用。也适用于普通 HTTP/fetch 无法满足的场景：页面依赖 JavaScript/AJAX 渲染、需要交互操作、需要视觉输出、遇到反爬或动态内容。**当用户要求为 Obscura 配置/修改代理、设置浏览器代理、配置 stealth 反爬、设置 User-Agent、允许访问内网、查看/修改 Obscura 运行时配置（obscura.env）时，也必须使用本技能**。本技能通过 obscura MCP 服务调用本地 headless 浏览器能力。
---

# Obscura 浏览器

## 目标

当用户要求打开网页、查看网页内容、搜索网页、提取页面信息、执行浏览器交互或截图时，主动使用 obscura MCP 提供的浏览器工具完成，全程用中文反馈。不要等用户手动提醒"用浏览器"。

## 如何连接（动态发现，不要猜测地址）

1. 先读取系统内置的 `lazycat-local-resource` skill（`/lzcapp/run/resources/skills/system/lazycat-local-resource.skill/SKILL.md`），按它给出的规则发现当前微服可用的 MCP provider。
2. 在 `/lzcapp/run/resources/mcp-providers/` 下找到 `obscura` provider，读取其 `mcp.yml` 中的 `endpoint` 字段。
3. 按 `.lzcx` 应用间访问规则拼接完整地址：`http://app.<package-id>.lzcx<endpoint>`。
4. 若当前环境无法解析 `.lzcx`：直接连接网关 IP，但请求的 `Host` 头必须保持为 `app.<package-id>.lzcx`；也可以通过当前微服的外部域名访问该应用的 MCP 地址。
5. 连接后使用 `browser_*` 系列工具。MCP 服务保持一个活动浏览器会话：**先 `browser_navigate` 导航，再读取或操作**，工具操作的是当前页面而不是每次传 URL。

## 工作流程

1. **打开页面**：`browser_navigate`（参数 `url`）。
2. **读取内容**：`browser_markdown`（页面转 Markdown）、`browser_snapshot`
   （当前 URL、标题、正文、可交互元素引用，可选 `max_chars` 限制返回
   长度）、`browser_links`（链接列表）、`browser_extract`（结构化内容）、
   `browser_get_attribute` / `browser_count` / `browser_search`（属性、
   计数、文本查找）。
3. **交互操作**：`browser_click` / `browser_fill` / `browser_fill_form` /
   `browser_type` / `browser_press_key` / `browser_select_option` /
   `browser_scroll`。操作前先 `browser_snapshot` 或
   `browser_interactive_elements` / `browser_detect_forms` 获取元素引用
   或表单字段信息。
4. **等待与执行 JS**：`browser_wait_for` / `browser_wait_for_text` 等待
   页面状态；`browser_evaluate` 执行任意 JavaScript 并返回结果。
5. **诊断**：`browser_network_requests` / `browser_console_messages` 查看
   页面网络请求与控制台信息。
6. **视觉输出**：`browser_screenshot`（当前视口 PNG，可选 `width`/`height`
   指定 CSS 像素尺寸，有大小上限）；`browser_pdf`（当前页 PDF，支持
   `landscape`、`print_background`、`scale`、纸张宽高与页边距参数，
   纸张尺寸与页边距单位为英寸）。
7. **标签页**：`browser_tab_new` / `browser_tab_list` / `browser_tab_switch`
   / `browser_tab_close` 管理多标签。
8. **Cookie 与存储**：`browser_get_cookies` / `browser_set_cookie` /
   `browser_clear_cookies` / `browser_storage_state` /
   `browser_set_storage_state` 管理会话数据。
9. **导航控制**：`browser_back` / `browser_forward` / `browser_reload` /
   `browser_close`。

## 登录态持久化（storage_state）

MCP 模式无文件级 Cookie 持久化（`--storage-dir` 仅 fetch/serve/scrape
支持，mcp 子命令未实现，上游 issue #629 请求中：支持 --storage-dir）。
进程重启后登录态丢失，通过 `browser_storage_state` / `browser_set_storage_state`
在 agent 侧持久化：

1. **保存登录态**：导航到目标站点 → 引导/等待用户登录完成 → 调用
   `browser_storage_state` 导出 JSON（cookies + localStorage +
   sessionStorage）→ 保存到长期位置（用户文档目录/记忆），供后续会话使用。
2. **恢复登录态**：会话开始需要登录态时，先调用 `browser_set_storage_state`
   传入之前导出的 JSON，再 `browser_navigate` 到目标页面。
3. **安全**：导出的 JSON 包含 Cookie/认证令牌，属于敏感数据——不得在
   对话回复中展示、不得写入日志或长期记忆（记忆只保存"该站点需要先恢复
   登录态"这类元信息）。
4. 会话内临时操作 Cookie 可直接用 `browser_get_cookies` /
   `browser_set_cookie` / `browser_clear_cookies`。

## 代理与运行时配置（obscura.env）

浏览器网络出口可通过配置文件动态调整（无需重装应用）。容器启动时入口
脚本读取 `/data/config/obscura.env`，拼装 `--proxy` / `--stealth` 等
启动参数。

### 配置文件格式

路径：`/data/config/obscura.env`（容器内），即应用数据目录下的
`config/obscura.env`。KEY=VALUE 每行一个，支持 `#` 注释，修改后**重启
容器生效**：

```ini
# 代理 URL，支持 http:// 和 socks5:// 两种协议。
# ⚠️ 协议前缀必须与代理实际类型一致（写错会导致访问失败）：
#   HTTP 代理 → PROXY=http://192.168.1.100:8080
#   SOCKS5 代理 → PROXY=socks5://192.168.1.100:1080
PROXY=http://192.168.1.100:8080
# 1 = 启用 stealth（一致指纹 + 广告/追踪拦截），反爬站点建议开启
STEALTH=1
# 自定义 User-Agent（可选）
USER_AGENT=Mozilla/5.0 (Windows NT 10.0; Win64; x64)
# 1 = 允许访问内网/回环地址（默认禁止，SSRF 防护）
ALLOW_PRIVATE_NETWORK=1
```

### 修改途径（用户手动）

在懒猫网盘中导航到该应用的数据目录 `config/` 下，创建/编辑
`obscura.env`（应用数据目录为 `ink.akawa.ety001.obscura`）。保存后按
下方"生效方式"重启容器。

### 生效方式

配置文件修改后需重启容器：
`/lzcsys/bin/lzc-docker restart inkakawaety001obscura-obscura-1`
（或重装应用）。重启后可用
`/lzcsys/bin/lzc-docker exec inkakawaety001obscura-obscura-1 /bin/busybox ps w`
确认 `--proxy` / `--stealth` 等参数是否出现在进程命令行。

## 注意事项

- **视觉输出无 CJK 字体（能力边界）**：渲染引擎只内嵌 Latin 字体
  （Liberation/DejaVu）和 emoji，不扫描系统字体。`browser_screenshot` /
  `browser_pdf` 中东亚文字（中/日/韩）会显示为方块。**文本提取不受影响**：
  `browser_markdown` / `browser_snapshot` / `browser_extract` 返回的字符
  数据在小龙猫端正常展示。需要向用户呈现中文页面内容时，优先用文本提取
  而非截图。**CJK 截图支持已提交上游 issue
  （https://github.com/h4ckf0r0day/obscura/issues/606），等待上游开发
  内嵌 CJK 字体或外部字体目录开关**。
- **元素引用会过期**：元素引用描述当前渲染页面状态，导航、交互、滚动
  或框架重渲染后可能失效。操作前重新获取 snapshot 或 interactive
  elements 列表。
- **无持久化会话**：浏览器会话不持久化 Cookie/存储，进程重启后登录态
  丢失；需要登录态的页面先通过 Cookie 工具导入。
- **视觉输出为静态图**：MCP 只提供截图/PDF 静态输出，不流式输出视频帧。
- **网络出口**：浏览器运行在懒猫微服容器内，网络出口为微服网络。
- 遇到 Cloudflare、JS Challenge、403、访问被拦截、页面依赖 JavaScript
  但正文为空等情况时，优先使用本技能重试。
- 不在最终回答中泄露 Cookie、认证令牌、凭据或原始敏感值。

## 错误处理

所有失败都用中文说明，并给出下一步建议。导航失败时检查 URL 是否正确、
是否需要等待（`browser_wait_for`）；元素找不到时重新获取 snapshot 后重试。
