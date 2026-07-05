FROM debian:bookworm-slim

# 复用 lazyCat 的入口约定: contentdir 打包到 /lzcapp/pkg/content
# init0 为容器入口, 由 supervisord 拉起 mihomo / cronie

ARG MIHOMO_VERSION=v1.19.27
ARG METACUBEXD_REPO=MetaCubeX/metacubexd

ENV DEBIAN_FRONTEND=noninteractive

# 基础依赖: supervisor 管进程, cronie 定时拉配置, curl 下载
# (面板由 mihomo 的 external-ui 直接托管, 无需额外 Web 服务)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        supervisor \
        cron \
        ca-certificates \
        curl \
        gzip \
        tar \
        tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 下载 mihomo 内核 (compatible 版, 兼容更多 CPU 微架构)
RUN mkdir -p /opt/mihomo && \
    curl -fsSL -o /tmp/mihomo.gz \
        "https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-amd64-compatible-${MIHOMO_VERSION}.gz" && \
    gunzip /tmp/mihomo.gz && \
    mv /tmp/mihomo /opt/mihomo/mihomo && \
    chmod +x /opt/mihomo/mihomo

# 下载 metacubexd 面板静态资源 (由 mihomo external-ui 托管)
RUN mkdir -p /opt/metacubexd && \
    curl -fsSL -o /tmp/ui.tgz \
        "https://github.com/${METACUBEXD_REPO}/releases/latest/download/compressed-dist.tgz" && \
    tar -xzf /tmp/ui.tgz -C /opt/metacubexd --strip-components=1 && \
    rm -f /tmp/ui.tgz

# supervisor 运行目录
RUN mkdir -p /var/log/supervisor /var/run/supervisor

COPY supervisord.conf     /etc/supervisor/supervisord.conf
COPY mihomo.conf          /etc/supervisor/entrypoints/mihomo.conf
COPY cron.conf.entry      /etc/supervisor/entrypoints/cron.conf
COPY update-config.sh     /opt/mihomo/update-config.sh
COPY start-mihomo.sh      /opt/mihomo/start-mihomo.sh
COPY crontab              /etc/cron.d/update-config
# 默认配置: 既打包进镜像 (/opt/mihomo/default-config.yaml, 二级兜底),
# 也随 contentdir 注入 (/lzcapp/pkg/content/default-config.yaml, 懒猫环境优先用)
COPY default-config.yaml  /opt/mihomo/default-config.yaml

RUN chmod +x /opt/mihomo/update-config.sh /opt/mihomo/start-mihomo.sh && \
    chmod 0644 /etc/cron.d/update-config && \
    crontab /etc/cron.d/update-config

# 7890 = mixed 代理端口 (HTTP/SOCKS5)
# 8001 = HTTP 代理端口
# 1081 = SOCKS5 代理端口
# 9090 = mihomo external-controller + external-ui (面板/API)
EXPOSE 7890 8001 1081 9090

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
