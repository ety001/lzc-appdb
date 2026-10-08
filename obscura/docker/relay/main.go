// relay: 极简并发 TCP 转发器。
//
// obscura 0.2.3 起 MCP HTTP 拒绝"非回环绑定且未设 OBSCURA_MCP_TOKEN"的实例，
// 而 lzc 的 mcp.yml 无法给客户端携带 Authorization 头，token 方案走不通。
// 因此容器内 obscura 绑 127.0.0.1（免 token），由本程序把 0.0.0.0 的端口
// 原样转发到回环口，暴露面与 0.2.1 部署一致（仅 lzc 应用网络内可达）。
//
// 用法: relay <listen-addr> <forward-addr>
// 构建: CGO_ENABLED=0 go build -trimpath -ldflags "-s -w" -o relay .
package main

import (
	"io"
	"log"
	"net"
	"os"
	"time"
)

const (
	// 健康检查间隔与连续失败阈值：obscura 崩溃后 relay 退出，
	// 容器随 PID1 退出被平台重启拉起，两个进程同生共死。
	watchInterval  = 5 * time.Second
	watchFailLimit = 2
	dialTimeout    = 2 * time.Second
)

func main() {
	if len(os.Args) != 3 {
		log.Fatalf("usage: relay <listen-addr> <forward-addr>")
	}
	listen, forward := os.Args[1], os.Args[2]

	ln, err := net.Listen("tcp", listen)
	if err != nil {
		log.Fatalf("listen %s: %v", listen, err)
	}
	log.Printf("relay %s -> %s", listen, forward)

	go func() {
		for {
			conn, err := ln.Accept()
			if err != nil {
				log.Printf("accept: %v", err)
				os.Exit(1)
			}
			go pipe(conn, forward)
		}
	}()

	watch(forward)
}

// pipe 单连接双向拷贝，断开任一方向即关闭整条连接。
func pipe(client net.Conn, forward string) {
	defer client.Close()
	upstream, err := net.DialTimeout("tcp", forward, dialTimeout)
	if err != nil {
		log.Printf("dial %s: %v", forward, err)
		return
	}
	defer upstream.Close()
	done := make(chan struct{}, 2)
	go func() { io.Copy(upstream, client); upstream.Close(); done <- struct{}{} }()
	go func() { io.Copy(client, upstream); client.Close(); done <- struct{}{} }()
	<-done
}

// watch 周期探测上游：启动阶段允许未就绪，一旦探活成功后再连续失败
// 视为 obscura 已退出，relay 随之退出交还给平台重启。
func watch(forward string) {
	alive := false
	fails := 0
	for {
		conn, err := net.DialTimeout("tcp", forward, dialTimeout)
		if err == nil {
			conn.Close()
			alive = true
			fails = 0
		} else if alive {
			fails++
			log.Printf("watch: %s unreachable (%d/%d): %v", forward, fails, watchFailLimit, err)
			if fails >= watchFailLimit {
				log.Fatalf("forward target %s is down, exiting", forward)
			}
		}
		time.Sleep(watchInterval)
	}
}
