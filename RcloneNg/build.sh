#!/bin/bash

# 该脚本不适用于放入 lzc-build.yml 中
# 因为 lzc-cli build 运行后, 最终的 manifest.yml 就不会再被修改

# 生成随机 tag（16位十六进制字符串）
RANDOM_TAG=$(openssl rand -hex 8)
echo "生成的随机 tag: $RANDOM_TAG"

# 使用随机 tag 构建镜像
docker build --push \
    --build-arg HTTPS_PROXY=http://192.168.199.11:8001 \
    -t ety001/rclone-ng:$RANDOM_TAG \
    -t ety001/rclone-ng:latest \
    ./docker

echo "开始复制镜像..."

# 执行 copy-image 命令并捕获输出
OUTPUT=$(lzc-cli appstore copy-image ety001/rclone-ng:$RANDOM_TAG 2>&1)
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
# 匹配冒号后面的任何标签（包括 master、latest、版本号、哈希值等）
sed -i "s|\(image: registry\.lazycat\.cloud/ety001/ety001/rclone-ng:\)[^[:space:]#]*|\1$IMAGE_HASH|g" lzc-manifest.yml

# 确保文件写入完成并刷新文件系统缓存
sync
sleep 1

# 验证更新是否成功
if grep -q "image: registry.lazycat.cloud/ety001/ety001/rclone-ng:$IMAGE_HASH" lzc-manifest.yml; then
    echo "✓ 已更新 lzc-manifest.yml 中的镜像标签为: registry.lazycat.cloud/ety001/ety001/rclone-ng:$IMAGE_HASH"
    echo "验证文件内容:"
    grep "image:" lzc-manifest.yml
else
    echo "✗ 错误: 更新 lzc-manifest.yml 失败"
    echo "当前文件内容:"
    grep "image:" lzc-manifest.yml
    exit 1
fi

echo "清理已有安装包..."
rm -rf ./*.lpk