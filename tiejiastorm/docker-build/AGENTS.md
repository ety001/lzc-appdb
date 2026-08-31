# 铁甲风暴 Docker 镜像编译指南

本目录是 `ety001/tiejiafengbao` 镜像的完整构建工程（源：nuc `~/workspace/tie/docker-build/`）。
镜像内容：Debian trixie-slim + DosWasmX 前端（含补丁）+ Windows 95 镜像 + CD 音轨，
容器启动后只是一个静态文件服务（python http.server :6080），模拟器跑在浏览器里。

## 编译步骤

### 1. 前置资源准备（本目录缺省不含大资源，见下节"资源文件"）

需要先补齐两个资源到 `game/` 下（NAS 已有存档）：

```bash
# windows95.img（300MB，含 mk.exe 补丁版）—— 从 NAS 取
cp "/run/user/1000/gvfs/smb-share:server=192.168.199.30,share=家庭共享/游戏/doswasmx-final-v3.7.1.tar 内含"  # 或见下方说明
```

`windows95.img` 的两种来源：
- **打补丁版**（推荐）：从镜像 tar（NAS `游戏/doswasmx-final-v3.7.1.tar`）解出，或从旧镜像容器里拷出
- **原版 + 手工补丁**：NAS `游戏/铁甲风暴完美版/windows95.img`（原版），
  挂载后对 `Program Files/Metal Knight/mk.exe` 打补丁：
  文件偏移 `0x80D78`：`74 3A` → `EB 3A`（跳过 CD 检测弹窗；**0x809B8 处不能改**，改了必崩）
  挂载命令：`sudo mount -o loop,offset=32256,rw windows95.img /mnt/w95`

```bash
# CD 文件（454MB）—— 从 NAS 取原始 CD 并重新生成 PCM
mkdir -p game/CD
cp "/run/user/1000/gvfs/smb-share:server=192.168.199.30,share=家庭共享/游戏/铁甲风暴完美版/CD/"* game/CD/
# 把 OGG 音轨转成裸 PCM（DosWasmX 的 AudioFile 解码器是空壳，必须走 BINARY/PCM 路径）
cd game/CD
for f in Track*.ogg; do
  n="${f%.ogg}"
  ffmpeg -y -v error -i "$f" -acodec pcm_s16le -ar 44100 -ac 2 -f s16le "${n}.bin"
done
# 生成 BINARY 格式 cue（数据轨 + AUDIO 轨全部声明为 BINARY）
# 参考本仓库 git 历史中的 "Dark Front.cue"（每个 FILE 用 BINARY 类型，TRACK 02-12 AUDIO）
```

### 2. 构建

```bash
cd docker-build
docker build --network=host -t ety001/tiejiafengbao:latest .
```

- **必须 `--network=host`**：nuc 宿主 DNS 全是 IPv6 ULA，bridge 容器内解析不了任何域名（拉基础镜像层/apt 都会失败）
- 基础镜像 `debian:trixie-slim`（bookworm 无所需包，trixie 有）
- 产物约 904MB（ uncompressed ）

### 3. 推送与部署

```bash
# Docker Hub（提交商店用 copy-image 的源）
docker push ety001/tiejiafengbao:latest

# 懒猫应用商店流程：把 Hub 镜像转存官方 registry
lzc-cli appstore copy-image ety001/tiejiafengbao:latest
# 拿到输出的 registry.lazycat.cloud/... 地址，更新上层 ../lzc-manifest.yml 的 image 字段，
# 然后在上层目录 lzc-cli project build && lzc-cli app install
```

## 文件清单

### 进 git 的文件（本目录现有）

| 文件 | 说明 |
|---|---|
| `Dockerfile` | 镜像构建定义（debian:trixie-slim，拷 game/ 到 /opt/game，暴露 6080）|
| `entrypoint.sh` | 容器入口：`cd /opt/game && python3 -m http.server 6080` |
| `.dockerignore` | 排除 `*.bak-esdi` 备份文件（曾导致镜像膨胀到 985MB）|
| `game/index.html` | DosWasmX 页面（含两处菜单的 Send Esc 按钮）|
| `game/script.js` | 前端核心补丁：CD 自动预加载(12文件) + autoexec 自动挂载 CD + 浏览器热键 v2 + sendEsc |
| `game/settings.js` | `DEFAULTIMG: windows95.img` + `DEFAULTCD: CD/Dark Front.cue` |
| `game/dosbox-x-for-web.conf` | DOSBox-X 配置：memsize=128、sensitivity=85、cd-rom insertion delay=0、-ide 2m 挂载 |
| `game/main.wasm` | DosWasmX 官方编译产物（DOSBox-X WASM 模拟器本体，10.7MB）|
| `game/main.js` / `main.ttf` / `input_controller.js` / `romlist.js` | DosWasmX 官方 dist 其余文件（未修改）|

### 资源文件（gitignore 忽略，**已存 NAS**）

NAS 路径：`smb://192.168.199.30/家庭共享/游戏/`（nuc 挂载点
`/run/user/1000/gvfs/smb-share:server=192.168.199.30,share=家庭共享/游戏/`）

| 文件 | 大小 | NAS 位置 |
|---|---|---|
| `game/windows95.img` | 300MB | `游戏/doswasmx-final-v3.7.1.tar` 内含打补丁版；`游戏/铁甲风暴完美版/windows95.img` 为原版 |
| `game/CD/Track01.iso` | 230MB | `游戏/铁甲风暴完美版/CD/Track01.iso` |
| `game/CD/Track02-12.bin` | 共214MB | 由 `游戏/铁甲风暴完美版/CD/Track02-12.ogg` 用 ffmpeg 重新生成（命令见上）|
| `game/CD/Dark Front.cue` | 821B | git 历史中有（本仓库 tiejiastorm/docker-build 提交），或按上节格式重建 |

另有整镜像级备份：`doswasmx-final-v3.7.1.tar`（866MB，docker save 导出）也在 NAS `游戏/` 下，
`docker load -i` 即可恢复最终镜像，无需重新编译。

### 离线 tar 恢复（最全的找回方式）

`doswasmx-final-v3.7.1.tar` 就是 `ety001/tiejiafengbao:latest` 镜像的 docker save 导出
（同一镜像 ID `83f219969855`，含全部 gitignore 资源：windows95.img、cue、Track01.iso、
Track02-12.bin——已实测逐层核对）。注意 tar 内记录的 RepoTag 是制作时的名字
`dev.ecat.heiyu.space/ety001/doswasmx:hotkey2-1788125273`，load 后需重新打 tag：

```bash
# 从 NAS tar 直接恢复完整镜像（不需要重新编译）
docker load -i /path/to/doswasmx-final-v3.7.1.tar
# load 进来的 tag 是旧名，重新打 tag
docker tag dev.ecat.heiyu.space/ety001/doswasmx:hotkey2-1788125273 ety001/tiejiafengbao:latest
docker run -d --name tiejiafengbao -p 6080:6080 ety001/tiejiafengbao:latest

# 如果只需要 tar 里的某个资源文件（如 windows95.img），不用 load，直接解层：
# 游戏数据在 manifest.json 的第 4 个 layer（index 3），解开即得 /opt/game 全部 24 个文件
python3 - <<'EOF'
import tarfile, json, io
t = tarfile.open("doswasmx-final-v3.7.1.tar")
m = json.load(t.extractfile("manifest.json"))
inner = tarfile.open(fileobj=io.BytesIO(t.extractfile(m[0]["Layers"][3]).read()))
inner.extractall("game-from-tar", members=[n for n in inner.getnames() if "/opt/game/" in n])
EOF
```

## LPK 工程文件说明

nuc 源目录下的 `icon.png / lzc-build.yml / lzc-manifest.yml / package.yml / mk.ico` 是
**旧版 LPK 工程遗留副本**（内容已过时），未拷贝到本目录——当前权威 LPK 工程在
`~/workspace/lzc-appdb/tiejiastorm/`（上层目录）。
