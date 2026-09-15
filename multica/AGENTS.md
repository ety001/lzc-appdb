# Multica 维护记录

## 上架状态：无法上架

Multica 因协议问题无法上架懒猫应用商店（package.yml 中的 license 为
"SEE LICENSE IN LICENSE"，其许可证条款不允许通过应用商店分发）。
本目录下的 LPK 仅用于自用/本地部署。

## 镜像策略

由于不再走应用商店上架流程，manifest 中的镜像直接引用官方源，
不再做 skopeo 中转 + `lzc-cli appstore copy-image` 到懒猫 registry：

- backend: `ghcr.io/multica-ai/multica-backend:latest`
- web: `ghcr.io/multica-ai/multica-web:latest`
- postgres: `pgvector/pgvector:pg17`

注意：`build.sh` 里的 `sync` / `copy` 子命令是上架时代的中转流程，
其中 `copy` 会用 sed 把 manifest 的镜像地址改回 `registry.lazycat.cloud`，
**不要再执行**，否则会覆盖掉官方镜像地址。日常构建/安装用
`./build.sh lpk`、`./build.sh install` 即可。

## 后续维护要点

- 官方发新版后，重新 `lzc-cli project build` 并自装即可，无需更新 registry 镜像。
- 如果懒猫盒子无法直接拉取 ghcr.io，需要自建代理或手动导入镜像到盒子。
