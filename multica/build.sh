#!/usr/bin/env bash
# Multica 懒猫微服 LPK 构建脚本
#
# 架构：postgres(pgvector/pg17) + backend(Go API:8080) + web(Next.js:3000)
# 官方镜像只在 ghcr.io（Docker Hub 无官方镜像），懒猫 copy-image 只认 Docker Hub，
# 所以用 skopeo 做字节级中转（不重新构建源码）：
#   ghcr.io/multica-ai/multica-backend:latest  ->  docker.io/ety001/multica-backend:latest-ghcr
#   ghcr.io/multica-ai/multica-web:latest      ->  docker.io/ety001/multica-web:latest-ghcr
#   pgvector/pgvector:pg17                     ->  docker.io/ety001/multica-pgvector:pg17
# 然后逐个 lzc-cli appstore copy-image，把返回的 registry.lazycat.cloud 地址更新进 manifest。
#
# 用法：
#   ./build.sh sync       # skopeo 中转镜像到 Docker Hub（需 docker hub 登录）
#   ./build.sh copy       # copy-image 到懒猫 registry 并更新 manifest 镜像地址
#   ./build.sh lpk        # 构建 LPK（不碰镜像）
#   ./build.sh install    # 卸载重装到懒猫微服（路由变更必须卸载重装才生效）
#   ./build.sh params     # 部署参数兜底写入（install 后若没弹参数界面）
set -euo pipefail

DOCKERHUB_USER="${DOCKERHUB_USER:-ety001}"
APPDIR="$(cd "$(dirname "$0")" && pwd)"

sync_images() {
  skopeo copy --all docker://ghcr.io/multica-ai/multica-backend:latest docker://docker.io/$DOCKERHUB_USER/multica-backend:latest-ghcr
  skopeo copy --all docker://ghcr.io/multica-ai/multica-web:latest      docker://docker.io/$DOCKERHUB_USER/multica-web:latest-ghcr
  skopeo copy --all docker://pgvector/pgvector:pg17                     docker://docker.io/$DOCKERHUB_USER/multica-pgvector:pg17
}

copy_images() {
  local be web pg
  be="$(lzc-cli appstore copy-image $DOCKERHUB_USER/multica-backend:latest-ghcr | grep -o 'registry.lazycat.cloud/\S*')"
  web="$(lzc-cli appstore copy-image $DOCKERHUB_USER/multica-web:latest-ghcr | grep -o 'registry.lazycat.cloud/\S*')"
  pg="$(lzc-cli appstore copy-image $DOCKERHUB_USER/multica-pgvector:pg17 | grep -o 'registry.lazycat.cloud/\S*')"
  sed -i \
    -e "s#image: registry.lazycat.cloud/\S*multica-backend:\S*#image: $be#" \
    -e "s#image: registry.lazycat.cloud/\S*multica-web:\S*#image: $web#" \
    -e "s#image: registry.lazycat.cloud/\S*multica-pgvector:\S*#image: $pg#" \
    -e "s#image: ghcr.io/multica-ai/multica-backend:.*#image: $be#" \
    -e "s#image: ghcr.io/multica-ai/multica-web:.*#image: $web#" \
    -e "s#image: pgvector/pgvector:pg17#image: $pg#" \
    "$APPDIR/lzc-manifest.yml"
  echo "manifest 镜像地址已更新"
}

build_lpk() {
  cd "$APPDIR"
  rm -f ./*.lpk
  lzc-cli project build
}

install_app() {
  cd "$APPDIR"
  lzc-cli app uninstall ink.akawa.ety001.multica || true
  sleep 8
  lzc-cli app install
  ./build.sh params
  ssh root@192.168.199.52 "timeout 120 /lzcsys/bin/lpk-manager start ink.akawa.ety001.multica | tail -1"
}

write_params() {
  ssh root@192.168.199.52 "printf '%s' '{\"app_env\":\"production\",\"allow_signup\":true,\"resend_api_key\":\"\",\"resend_from_email\":\"\",\"smtp_host\":\"\",\"smtp_port\":\"25\",\"smtp_username\":\"\",\"smtp_password\":\"\",\"smtp_from_email\":\"\",\"pg_db\":\"multica\",\"pg_user\":\"multica\"}' > /lzcsys/data/system/pkgm/deploy.var/ink.akawa.ety001.multica/deploy_params_value.json"
}

case "${1:-lpk}" in
  sync)   sync_images ;;
  copy)   copy_images ;;
  lpk)    build_lpk ;;
  install) install_app ;;
  params) write_params ;;
  *) echo "用法: $0 {sync|copy|lpk|install|params}"; exit 1 ;;
esac
