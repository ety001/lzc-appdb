FROM alpine:3.22.2

# 定义 rclone 版本号构建参数，默认版本 v1.71.2
ARG RCLONE_VERSION=v1.71.2

# 安装必要的软件包（移除 rclone，将从 GitHub 下载）
RUN apk add --no-cache \
    supervisor \
    cronie \
    bash \
    ca-certificates \
    tzdata \
    curl \
    unzip \
    && rm -rf /var/cache/apk/*

# 从 GitHub releases 下载并安装指定版本的 rclone（仅支持 x86/amd64 架构）
RUN curl -L -o /tmp/rclone.zip \
    "https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-amd64.zip" \
    && unzip -q /tmp/rclone.zip -d /tmp \
    && mv /tmp/rclone-${RCLONE_VERSION}-linux-amd64/rclone /usr/bin/rclone \
    && chmod +x /usr/bin/rclone \
    && rm -rf /tmp/rclone.zip /tmp/rclone-${RCLONE_VERSION}-linux-amd64

# 创建必要的目录
RUN mkdir -p /etc/supervisor/conf.d && \
    mkdir -p /var/log/supervisor && \
    mkdir -p /var/run && \
    mkdir -p /root/.cache/rclone/webgui/current/build/ && \
    echo "v2.0.5" > /root/.cache/rclone/webgui/tag

# 复制 supervisor 配置文件
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY rclone-webui.conf /etc/supervisor/conf.d/rclone-webui.conf
COPY cronie.conf /etc/supervisor/conf.d/cronie.conf

# 复制 webui 文件
COPY webui/ /root/.cache/rclone/webgui/current/build/

# 创建启动脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 暴露端口
EXPOSE 8080

# 设置工作目录
WORKDIR /root

# 启动 supervisor
CMD ["/entrypoint.sh"]

