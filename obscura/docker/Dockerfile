# 薄镜像：官方 obscura + busybox(ash) 入口脚本，支持运行时配置（代理等）
# 官方镜像 distroless 无 shell，无法在容器启动时读配置；本层加静态 busybox
# 提供 ash，entrypoint 脚本读 /data/config/obscura.env 拼装启动参数。
# 构建用 ssd-builder 远端从 Docker Hub 拉取基础镜像并 push（见 lzc-appdb 说明）。
FROM h4ckf0r0day/obscura:0.2.1

COPY busybox /bin/busybox
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/bin/busybox", "ash", "/entrypoint.sh"]
