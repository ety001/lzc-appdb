#!/bin/bash

# 目标目录和压缩包路径
TARGET_DIR="/NarratoAI"
ARCHIVE="/lzcapp/pkg/content/NarratoAI-0.5.2.tar.gz"

# 检查目标目录是否存在且非空
if [ -d "$TARGET_DIR" ] && [ -n "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
    echo "目录 $TARGET_DIR 存在且不为空，停止初始化。"
    /bin/bash /NarratoAI/docker-entrypoint.sh webui
    exit 0
fi

# 确保压缩包存在
if [ ! -f "$ARCHIVE" ]; then
    echo "错误：压缩包 $ARCHIVE 不存在。"
    exit 1
fi

# 创建目标目录（如果不存在）
mkdir -p "$TARGET_DIR"

# 解压压缩包到目标目录
echo "正在解压 $ARCHIVE 到 $TARGET_DIR..."
tar -xzf "$ARCHIVE" -C "$TARGET_DIR" --strip-components=1

# 检查解压结果
if [ $? -eq 0 ]; then
    echo "解压完成。"
else
    echo "解压过程中出现错误。"
    exit 1
fi

# 字体
cp /lzcapp/pkg/content/SourceHanSansCN-Regular.otf /NarratoAI/resource/fonts/
cp /lzcapp/pkg/content/SourceHanSansSC-Regular.otf /NarratoAI/resource/fonts/

/bin/bash /NarratoAI/docker-entrypoint.sh webui
exit 0