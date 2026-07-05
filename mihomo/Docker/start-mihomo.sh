#!/bin/bash
# mihomo 启动入口
# 职责: 确保运行目录与运行配置就绪, 然后前台启动 mihomo
set -euo pipefail

# ---------- 路径约定 (持久化目录 /lzcapp/var) ----------
# 注意: mihomo 的 home directory (-d) 必须包含配置文件, 否则热加载会被
# SAFE_PATHS 安全机制拒绝。因此 home dir 直接用 /lzcapp/var,
# 运行数据放其子目录 run/。
VAR_DIR="/lzcapp/var"
RUNTIME_DIR="${VAR_DIR}/run"            # mihomo 运行数据 (cache.db / fakeip 等)
CONFIG_FILE="${VAR_DIR}/config.yaml"    # 实际运行配置

# 默认配置解析: 优先懒猫 contentdir, 不存在则用镜像内置兜底
resolve_default_config() {
    local pkg_cfg="/lzcapp/pkg/content/default-config.yaml"
    local img_cfg="/opt/mihomo/default-config.yaml"
    if [ -f "${pkg_cfg}" ]; then
        echo "${pkg_cfg}"
    elif [ -f "${img_cfg}" ]; then
        echo "${img_cfg}"
    else
        echo ""
    fi
}
DEFAULT_CONFIG="$(resolve_default_config)"

# ---------- 目录初始化 ----------
mkdir -p "${VAR_DIR}" "${RUNTIME_DIR}"

# ---------- 配置初始化 ----------
# 首次启动或运行配置被删时, 用默认配置兜底
if [ ! -f "${CONFIG_FILE}" ]; then
    if [ -z "${DEFAULT_CONFIG}" ]; then
        echo "[start-mihomo] 错误: 找不到任何默认配置, 退出" >&2
        exit 1
    fi
    echo "[start-mihomo] config.yaml 不存在, 使用默认配置: ${DEFAULT_CONFIG}"
    cp "${DEFAULT_CONFIG}" "${CONFIG_FILE}"
fi

# ---------- 启动 ----------
# SAFE_PATHS: mihomo v1.19.9+ 安全机制, 路径必须在 home dir 内或在此声明。
# 这里把 external-ui 面板目录加入允许列表 (home dir 已是 /lzcapp/var,
# 覆盖 config.yaml 和 run/)
export SAFE_PATHS="/opt/metacubexd"

# -d 指定 home directory (必须包含配置文件, 否则热加载会被拒绝)
# -f 指定配置文件
exec /opt/mihomo/mihomo \
    -d "${VAR_DIR}" \
    -f "${CONFIG_FILE}"
