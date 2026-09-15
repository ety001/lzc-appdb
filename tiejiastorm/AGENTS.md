# 铁甲风暴 (tiejiastorm) 维护记录

## 上架状态：无法上架

《铁甲风暴》(Metal Knight) 因版权/协议问题无法上架懒猫应用商店
（package.yml 中 license 为 "Freeware (Abandonware)"，属经典游戏的
非官方分发，商店审核不通过）。本目录下的 LPK 仅用于自用/本地部署。

## 镜像策略

manifest 直接引用自己的 Docker Hub 镜像，不再走
`lzc-cli appstore copy-image` 到懒猫 registry：

- `ety001/tiejiafengbao:latest`

之前 manifest 里的 `registry.lazycat.cloud/ety001/ety001/tiejiafengbao:10edc5a000b0cc67`
就是从这个镜像 copy-image 过来的（内容完全相同），现已替换回源镜像。

## 后续维护

- 完整项目档案（架构、CD 音轨方案、mk.exe 补丁、部署流程、排障）见同目录 `PROJECT.md`。
- 官方更新流程：nuc 上重新构建推送 `ety001/tiejiafengbao`（见 PROJECT.md 第七节），
  本机重新 `lzc-cli project build` + `lzc-cli app install` 即可，无需 copy-image。
