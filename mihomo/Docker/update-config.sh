#!/bin/bash
# 配置更新脚本 (由 cron 每5分钟触发)
#
# 逻辑:
#   1. 读取订阅地址: /lzcapp/var/subscribe_url.txt (取第一个非空行)
#      - 文件不存在 / 为空 -> 使用打包的默认配置, 不下载
#   2. curl 下载订阅内容到临时文件, 校验非空
#   3. 注入运行时必需字段 (external-controller / external-ui)
#      下载来的完整配置可能没有这两个字段, 或指向别处, 会导致面板失联
#   4. 下载成功且校验通过 -> 覆盖运行配置 -> 热加载 (调 mihomo API)
#   5. 任何步骤失败 -> 保留旧配置不动, 仅记日志
#
# 设计原则: 永不让一个坏配置替换掉能用的配置

set -uo pipefail

# ---------- 路径 ----------
VAR_DIR="/lzcapp/var"
CONFIG_FILE="${VAR_DIR}/config.yaml"          # 运行配置 (最终生效)
URL_FILE="${VAR_DIR}/subscribe_url.txt"        # 用户填写的订阅地址
TMP_CONFIG="${VAR_DIR}/.downloaded.yaml.tmp"   # 下载临时文件

# 默认配置解析: 优先懒猫 contentdir, 不存在则用镜像内置兜底
resolve_default_config() {
    local pkg_cfg="/lzcapp/pkg/content/default-config.yaml"
    local img_cfg="/opt/mihomo/default-config.yaml"
    if [ -f "${pkg_cfg}" ]; then
        echo "${pkg_cfg}"
    elif [ -f "${img_cfg}" ]; then
        echo "${img_cfg}"
    fi
}
DEFAULT_CONFIG="$(resolve_default_config)"

# mihomo external-controller (热加载用, 走容器内回环)
API_HOST="127.0.0.1:9090"
SECRET=""
# 若配置里有 secret, 从运行配置里读出来用于热加载鉴权
if [ -f "${CONFIG_FILE}" ]; then
    SECRET=$(grep -E '^\s*secret:\s*' "${CONFIG_FILE}" 2>/dev/null | head -n1 | sed -E 's/^\s*secret:\s*["'\'']?([^"'\'']*)["'\'']?\s*$/\1/' || true)
fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ---------- 注入运行时必需字段 ----------
# 确保 external-controller 指向 127.0.0.1:9090, external-ui 指向 metacubexd 目录
# 用 sed 而非 yq, 避免重序列化丢注释; 只动这两个键, 其余不动
inject_runtime_fields() {
    local file="$1"
    local ec_line="external-controller: 0.0.0.0:9090"
    local ui_line="external-ui: /opt/metacubexd"

    # external-controller: 已存在则替换其值, 不存在则在末尾追加
    if grep -qE '^[[:space:]]*external-controller[[:space:]]*:' "${file}"; then
        sed -i -E "s|^[[:space:]]*external-controller[[:space:]]*:.*|${ec_line}|" "${file}"
    else
        printf '\n%s\n' "${ec_line}" >> "${file}"
    fi

    # external-ui: 同理
    if grep -qE '^[[:space:]]*external-ui[[:space:]]*:' "${file}"; then
        sed -i -E "s|^[[:space:]]*external-ui[[:space:]]*:.*|${ui_line}|" "${file}"
    else
        printf '\n%s\n' "${ui_line}" >> "${file}"
    fi

    # TUN: 订阅配置通常不含 tun 段, 若不注入则热加载后 TUN 会被关闭。
    # 这里检测顶层 (行首无缩进) 是否已有 tun: 段;
    #   - 有 -> 订阅自带, 尊重其设置, 不覆盖
    #   - 无 -> 追加默认 TUN 段 (与本应用 default-config.yaml 一致)
    # 不用 sed 处理多行块 (易误伤), 改用 grep 判存在 + heredoc 追加。
    if ! grep -qE '^tun[[:space:]]*:' "${file}"; then
        cat >> "${file}" <<'TUN_BLOCK'

# ---------- TUN (由 update-config 注入) ----------
tun:
  enable: true
  stack: system
  dns-hijack:
    - any:53
  auto-route: true
  auto-detect-interface: true
  route-exclude-address:
    - 192.168.0.0/16
    - 172.16.0.0/12
    - 10.0.0.0/8
TUN_BLOCK
    fi
}

# ---------- 等待 mihomo 就绪 (最多 ~30s) ----------
wait_for_mihomo() {
    local i
    for i in $(seq 1 15); do
        if curl -fsS -o /dev/null "http://${API_HOST}/version" \
            ${SECRET:+-H "Authorization: Bearer ${SECRET}"} 2>/dev/null; then
            return 0
        fi
        sleep 2
    done
    return 1
}

# ---------- 热加载配置 ----------
reload_mihomo() {
    # PUT /configs?force=true 会让 mihomo 重新读取 -f 指定的配置文件
    if wait_for_mihomo; then
        local code
        code=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT \
            "http://${API_HOST}/configs?force=true" \
            ${SECRET:+-H "Authorization: Bearer ${SECRET}"} \
            -H "Content-Type: application/json" \
            -d "{\"path\": \"${CONFIG_FILE}\"}")
        if [ "${code}" = "204" ] || [ "${code}" = "200" ]; then
            log "热加载成功 (HTTP ${code})"
            return 0
        else
            log "热加载失败 (HTTP ${code})"
            return 1
        fi
    else
        log "mihomo 未就绪, 跳过热加载"
        return 1
    fi
}

# ---------- 主流程 ----------
main() {
    mkdir -p "${VAR_DIR}"

    # 1. 读取订阅地址
    local sub_url=""
    if [ -f "${URL_FILE}" ]; then
        # 取第一个非空、非注释行
        sub_url=$(grep -vE '^\s*(#|$)' "${URL_FILE}" 2>/dev/null | head -n1 | tr -d '[:space:]' || true)
    fi

    # 2. 没有订阅地址 -> 回退默认配置
    if [ -z "${sub_url}" ]; then
        log "未配置订阅地址 (${URL_FILE}), 使用默认配置"
        cp -f "${DEFAULT_CONFIG}" "${CONFIG_FILE}"
        reload_mihomo || true
        return 0
    fi

    log "开始下载订阅: ${sub_url}"

    # 3. 下载到临时文件 (失败重试2次)
    local ok=0
    local attempt
    for attempt in 1 2; do
        if curl -fsS --connect-timeout 10 --max-time 60 \
            -o "${TMP_CONFIG}" "${sub_url}"; then
            ok=1
            break
        fi
        log "下载失败 (第 ${attempt} 次), 重试..."
        sleep 3
    done

    if [ "${ok}" -ne 1 ]; then
        log "下载最终失败, 保留旧配置"
        rm -f "${TMP_CONFIG}"
        return 1
    fi

    # 4. 校验: 非空 + 体积合理 (>50 字节, 排除错误页)
    if [ ! -s "${TMP_CONFIG}" ]; then
        log "下载内容为空, 保留旧配置"
        rm -f "${TMP_CONFIG}"
        return 1
    fi
    local size
    size=$(wc -c < "${TMP_CONFIG}" | tr -d ' ')
    if [ "${size}" -lt 50 ]; then
        log "下载内容过小 (${size}B), 疑似错误页, 保留旧配置"
        rm -f "${TMP_CONFIG}"
        return 1
    fi

    # 5. 注入运行时必需字段 (关键!)
    #    下载来的完整配置可能没有这两个字段, 或指向别处, 会导致面板失联。
    #    用 sed 精准替换/插入这两个键, 保留配置其余内容与注释。
    inject_runtime_fields "${TMP_CONFIG}"

    # 6. 替换运行配置 + 热加载
    mv -f "${TMP_CONFIG}" "${CONFIG_FILE}"
    log "配置已更新 ($(wc -c < "${CONFIG_FILE}" | tr -d ' ')B)"
    reload_mihomo || true
}

main "$@"
