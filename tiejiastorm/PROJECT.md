# 铁甲风暴 DosWasmX 移植项目档案

> 更新时间：2026-08-31（项目完结：游戏声音/音乐完美复现，完美可玩）
> 应用：ink.akawa.ety001.tiejiastorm @ https://tiejiastorm.ecat.heiyu.space
> 最终版本：v3.7.1

## 〇、最终交付物（镜像名）

**当前线上运行镜像**（v3.8.0 商店发布版）：
```
registry.lazycat.cloud/ety001/ety001/tiejiafengbao:10edc5a000b0cc67
```
- 来源：`lzc-cli appstore copy-image ety001/tiejiafengbao:latest`（Docker Hub → 官方 registry）
- 镜像 ID：83f219969855（内容与 hotkey2-1788125273 完全相同）
- 容器：inkakawaety001tiejiastorm-tiejiastorm-1（懒猫微服）
- LPK：本目录 ink.akawa.ety001.tiejiastorm-v3.8.0.lpk（lint 干净，含 locales）
- **Docker Hub**：`ety001/tiejiafengbao:latest`（copy-image 源）
- **历史 dev registry 地址**：dev.ecat.heiyu.space/ety001/doswasmx:hotkey2-1788125273（已弃用）
- **nuc 本地离线备份**：~/workspace/tie/doswasmx-final-v3.7.1.tar（866MB，docker save 导出）

## 一、最终架构

**DosWasmX**（https://github.com/nbarkhina/DosWasmX）= DOSBox-X 的 Emscripten/WASM 移植，
模拟器跑在浏览器里，服务器只是静态文件托管（Debian trixie-slim + python http.server）。

- 浏览器加载 main.wasm（DOSBox-X）+ windows95.img（Win95 硬盘镜像）+ CD 文件
- 点 "Start Computer" → DOSBox-X 引导 Win95 → 桌面 → 双击 mk.exe 进游戏
- CD 音轨：cue + 裸 PCM (BINARY) → DOSBox-X CDROM BinaryFile 路径播放

## 二、关键文件位置

| 位置 | 路径 |
|---|---|
| nuc 构建目录 | ~/workspace/tie/docker-build/（Dockerfile + game/）|
| nuc DosWasmX 原始 dist | ~/workspace/tie/doswasmx/ |
| nuc 修改版 web | ~/workspace/tie/doswasmx-web/ |
| nuc 游戏原盘 | ~/workspace/tie/铁甲风暴DOSBox完美版/ |
| 本机 LPK 工程 | 本目录（~/workspace/lzc-appdb/tiejiastorm/，已入 lzc-appdb git 仓库）|
| 本机项目档案 | ~/workspace/tie/PROJECT.md（本文件）|
| 镜像仓库 | dev.ecat.heiyu.space/ety001/doswasmx:* |

## 三、CD 音轨方案（本项目核心突破）

DosWasmX 的 cdrom_image.cpp 把 SDL_Sound 解码器全部删了：
- AudioFile 类是空壳（decode 返回 0、seek 返回 false）→ cue 用 AUDIO 类型挂载必然失败
- **BinaryFile 类完整实现**，且硬编码 44100Hz/16bit/立体声/小端 = CD-DA 红皮书格式

**解法**：OGG → 裸 PCM 流，cue 里声明 BINARY：
```bash
ffmpeg -i Track02.ogg -acodec pcm_s16le -ar 44100 -ac 2 -f s16le Track02.bin
```
cue 片段：
```
FILE "Track02.bin" BINARY
  TRACK 02 AUDIO
    INDEX 01 00:00:00
```
体积代价：11 条音轨 ≈ 600MB PCM，镜像共 ~904MB。
已验证：游戏 CD 音乐完美播放。

## 四、mk.exe 补丁（跳过 CD 检测弹窗，保险用，已写入镜像）

- 文件偏移 0x80D78（VA 0x481978）：`74 3A` → `EB 3A`
  逻辑：test eax,eax 后无条件跳到正常初始化路径，跳过"弹 CD 错误框+退出"分支
- **警告**：0x809B8 处的 je（CD 对象初始化分支）**不能改**，改了必崩（非法操作 0137:004AABA8）
- PE 换算：VA = file_offset + 0x400C00
- mk.exe 887296 字节，位于镜像 /Program Files/Metal Knight/

## 五、windows95.img 注意事项

- FAT16，分区偏移 32256 字节（63×512）
- rw 挂载：`sudo mount -o loop,offset=32256,rw windows95.img /mnt/w95`
- 改镜像前务必备份（.bak-esdi 已有）

## 六、DosWasmX 前端补丁（script.js / index.html）

1. **CD 自动预加载**：启动时 fetch CD/*（12 文件）写入模拟器 FS
2. **CD 自动挂载**：autoexec 加 `imgmount d "Dark Front.cue" -t cdrom -ide 2m`
3. **Send Esc 按钮**：`myApp.sendEsc()` → `sendKey(49)`（Advanced 菜单两处）
4. **浏览器热键 v2**：Ctrl/Meta/Alt 组合 preventDefault 但放行事件给模拟器
   （Ctrl+编队键浏览器不响应、游戏可收到；注意不能加 stopPropagation，会掐死事件）
5. **全屏 Keyboard Lock**：全屏时 navigator.keyboard.lock() 拦截浏览器保留键
6. **dosbox-x-for-web.conf 最终值**：
   - `sensitivity=85`（鼠标灵敏度调低）
   - `memsize=128`（RAM 128MB，卡顿优化）
   - `cd-rom insertion delay=0`（原 4000ms 导致 Win95 引导时检测不到光驱）
   - script.js `this.ram = 128`

## 七、部署流程（以后更新照此执行）

```bash
# nuc 上：同步文件 → 构建镜像 → 推送
cd ~/workspace/tie/docker-build
docker build --network=host -t ety001/doswasmx:latest .
docker tag ety001/doswasmx:latest dev.ecat.heiyu.space/ety001/doswasmx:<tag>
docker push dev.ecat.heiyu.space/ety001/doswasmx:<tag>

# 本机：改 lzc-manifest.yml 镜像 tag + package.yml 版本号
lzc-cli project build
lzc-cli app uninstall ink.akawa.ety001.tiejiastorm
lzc-cli app install
```
注意：docker build 必须 --network=host（容器 DNS 挂）；基础镜像 debian:trixie-slim。

## 八、镜像版本历史（dev.ecat.heiyu.space/ety001/doswasmx）

- 1788103671: 首个 DosWasmX 版（无 CD）
- cd-1788110012: ISO 直挂数据轨版（D 盘可用，无音轨）
- pcmcue-1788117374: v3.6.0 裸 PCM 音轨版（CD 音乐成功）
- perf1-1788120987: RAM 64MB
- ram128-1788123609: v3.7.0 RAM 128MB + 热键屏蔽 v1
- **hotkey2-1788125273: v3.7.1 最终版（当前线上）**：热键 v2 + sensitivity=85 + RAM 128MB

## 九、已知限制（最终结论）

- **Esc 键在窗口模式无法拦截**（浏览器指针锁机制），游戏内 Esc 用 Advanced → Send Esc 按钮；
  全屏模式下 Esc 同样会先退指针锁（Keyboard Lock 拦不住 Esc 退锁），已接受此限制
- WASM 单线程 + Asyncify setTimeout 唤醒模型，性能上限固定
- 存档：浏览器 Save Drive（IndexedDB），换浏览器/清缓存会丢
- headless Chrome 会节流 rAF，自动化测试必须真实浏览器
- 镜像 windows95.img 是打了补丁的版本；原版未补丁镜像在 ~/workspace/tie/铁甲风暴DOSBox完美版/

## 十、排障速查

- D 盘消失 → 检查 CD 预加载日志 + cue 类型必须是 BINARY（AUDIO 类型 AudioFile 空壳必败）
- 游戏报"放入 CD" → 确认 imgmount d 执行 + cue 12 轨全挂载
- mk.exe 非法操作 0137:004AABA8 → 镜像里 mk.exe 的 0x809B8 被改了，还原为 74 5B
- 引导后无光驱 → cd-rom insertion delay 必须 =0
