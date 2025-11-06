#!/bin/bash

docker build --push --build-arg HTTPS_PROXY=http://192.168.199.11:8001 -t ety001/rclone-ng ./docker

sleep 30
echo "开始复制镜像..."

# 执行 copy-image 命令并捕获输出
OUTPUT=$(lzc-cli appstore copy-image ety001/rclone-ng:latest 2>&1)
echo "$OUTPUT"

# 从输出中提取镜像哈希值（格式：uploaded: registry.lazycat.cloud/ety001/ety001/rclone-ng:HASH）
# 提取最后一个冒号后面的16位十六进制哈希值
IMAGE_HASH=$(echo "$OUTPUT" | sed -n 's/.*:\([0-9a-f]\{16\}\)$/\1/p')

if [ -z "$IMAGE_HASH" ]; then
    echo "错误: 无法从输出中提取镜像哈希值"
    echo "输出: $OUTPUT"
    exit 1
fi

echo "提取的镜像哈希: $IMAGE_HASH"

# 更新 lzc-manifest.yml 中的镜像标签
sed -i "s|image: registry\.lazycat\.cloud/ety001/ety001/rclone-ng:[0-9a-f]\{16\}|image: registry.lazycat.cloud/ety001/ety001/rclone-ng:$IMAGE_HASH|" lzc-manifest.yml

echo "已更新 lzc-manifest.yml 中的镜像标签为: registry.lazycat.cloud/ety001/ety001/rclone-ng:$IMAGE_HASH"

echo "清理已有安装包..."
rm -rf ./*.lpk