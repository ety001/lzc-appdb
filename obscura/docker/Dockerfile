# 薄镜像：官方 obscura + busybox(ash) 入口脚本 + relay TCP 转发器，支持运行时配置（代理等）
# 官方镜像 distroless 无 shell，无法在容器启动时读配置；本层加静态 busybox
# 提供 ash，entrypoint 脚本读 /data/config/obscura.env 拼装启动参数。
# relay/：Go 极简并发 TCP 转发器（源码同目录，CGO_ENABLED=0 静态编译）。
# 0.2.3 起 MCP HTTP 非回环绑定强制 OBSCURA_MCP_TOKEN（>=32 字节），而 lzc
# 的 mcp.yml 无法给客户端携带 Authorization 头，故 obscura 绑 127.0.0.1
# （免 token）、relay 把 0.0.0.0 转发到回环口，暴露面与 0.2.1 部署一致
# （仅 lzc 应用网络内可达），详见 entrypoint.sh 注释。
# 构建用 ssd 远端 builder 从 Docker Hub 拉取基础镜像并 push（见 lzc-appdb 说明）。
FROM h4ckf0r0day/obscura:0.2.4

COPY busybox /bin/busybox
COPY entrypoint.sh /entrypoint.sh
COPY relay/relay /relay

ENTRYPOINT ["/bin/busybox", "ash", "/entrypoint.sh"]
