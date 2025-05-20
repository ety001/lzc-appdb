package main

import (
	"flag"
	"log"
	"net/http"
)

func main() {
	dir := flag.String("d", ".", "网站根目录")
	port := flag.String("p", "8080", "监听端口")
	flag.Parse()

	// 注册静态文件处理器
	http.Handle("/", http.FileServer(http.Dir(*dir)))

	log.Printf("服务器启动中... 目录：%s, 端口: %s", *dir, *port)
	err := http.ListenAndServe(":"+*port, nil)
	if err != nil {
		log.Fatal("服务器启动失败: ", err)
	}
}
