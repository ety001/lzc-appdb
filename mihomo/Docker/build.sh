#!/bin/bash
# 构建并推送 mihomo 应用镜像
# tag 使用 commit 短 hash (与 lzc-manifest.yml 中 image 字段保持一致)
# 推送后, manifest 引用的完整地址为:
#   registry.lazycat.cloud/ety001/ety001/mihomo:<tag>

set -e

TAG="${1:-$(git rev-parse --short=16 HEAD)}"

docker build --push \
    -t "ety001/mihomo:${TAG}" \
    -f Dockerfile .
