Mihomo (Clash.Meta) for LazyCat
================================

本应用提供 mihomo 内核 + metacubexd 管理面板, 并支持定时从订阅地址更新配置。

【端口说明】
  7890  HTTP/SOCKS5 混合代理端口 (供设备连接走代理)
  8001  HTTP 代理端口
  1081  SOCKS5 代理端口
  9090  metacubexd 管理面板 + mihomo API (浏览器访问)
  所有端口均通过 lazyCat ingress 暴露, 免网关认证直连。

【访问面板】
  浏览器打开: http://懒猫局域网IP:9090/ui/
  面板由 mihomo 的 external-ui 托管 (挂在 /ui/ 路径下, 根路径 / 留给 API)。
  登录时, 后端地址(Host)填: http://懒猫局域网IP:9090 (secret 留空)。

【配置订阅地址】
  将你的订阅地址写入应用的 "应用数据/mihomo/subscribe_url.txt" 文件,
  每行一个地址, 取首个非注释行生效。
  示例内容:
      https://your-airport.example.com/sub?token=xxxx

  每 5 分钟会自动下载并热加载一次。
  下载后会自动注入 external-controller / external-ui 字段, 确保面板不会因
  订阅配置缺失这两个字段而失联。
  若 subscribe_url.txt 不存在或为空, 则使用默认配置 (无节点, 仅直连)。

【手动让其他设备走代理】
  局域网设备把代理指向 (按需任选其一):
    懒猫局域网IP:7890  (mixed, HTTP 和 SOCKS5 自动识别)
    懒猫局域网IP:8001  (仅 HTTP)
    懒猫局域网IP:1081  (仅 SOCKS5)

【应用数据目录】
  /lzcapp/var/                       (映射到 懒猫应用数据/mihomo/)
    ├── subscribe_url.txt             你的订阅地址
    ├── config.yaml                   实际运行配置 (勿手动改, 会被订阅覆盖)
    └── run/                          mihomo 运行数据
