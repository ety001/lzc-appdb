# Aira Personal Server (aira-sync) — upstream: https://github.com/mason173/aira-browser
# 仅 amd64；上下文目录传 services/personal-server 的完整源码目录
#
# 与上游 Dockerfile 的差异：以 root 启动，由 entrypoint 对 /data chown 后降权到 node(UID 1000)。
# 原因：lzc-manifest 的 run_as 依赖 pkgm 的 idmapped 挂载机制，部分盒子（如 lzcwlf01,
# lzcos 1.6.2）上 pkgm 准备 idmapped 目录报 EOVERFLOW，应用起不来。
# 改为容器内自行处理权限后，manifest 不再需要 run_as，兼容所有盒子。
FROM node:20-bookworm-slim AS dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:20-bookworm-slim
ENV NODE_ENV=production \
    AIRA_DATA_DIR=/data \
    AIRA_PORT=8787 \
    AIRA_HOST=0.0.0.0
WORKDIR /app
COPY --from=dependencies /app/node_modules ./node_modules
COPY package.json ./
COPY migrations ./migrations
COPY scripts ./scripts
COPY src ./src
RUN mkdir -p /data && chown -R node:node /app /data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
EXPOSE 8787
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8787/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
