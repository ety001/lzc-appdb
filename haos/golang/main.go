package main

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/exec"
	"sync"
	"time"
)

const (
	backendHost  = "127.0.0.1"
	backendPort  = "8123"
	kvmImagePath = "/haos/haos_ova.qcow2"
	scriptPath   = "/lzcapp/pkg/content/temp_run.sh"
)

var (
	scriptOutput bytes.Buffer
	outputMutex  sync.RWMutex
	outputChan   = make(chan string, 100)
)

func main() {
	// 启动脚本协程
	go runScript()

	// 后台协程不断从 channel 读取并写入缓冲区
	go func() {
		for line := range outputChan {
			outputMutex.Lock()
			scriptOutput.WriteString(line)
			outputMutex.Unlock()
		}
	}()

	// 启动 web 服务器协程
	go func() {
		http.HandleFunc("/", handler)
		http.HandleFunc("/api/check_backend", apiCheckBackend)
		http.HandleFunc("/api/script_output", apiScriptOutput)
		fmt.Println("Server listening on :8080")
		http.ListenAndServe(":8080", nil)
	}()

	// 阻塞主线程
	select {}
}

func runScript() {
	cmd := exec.Command("bash", scriptPath)
	stdout, _ := cmd.StdoutPipe()
	stderr, _ := cmd.StderrPipe()
	_ = cmd.Start()

	reader := io.MultiReader(stdout, stderr)
	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		line := scanner.Text()
		outputChan <- line + "\n" // 通过 channel 传递
	}
	cmd.Wait()
	close(outputChan) // 关闭 channel，通知后台协程结束
}

func handler(w http.ResponseWriter, r *http.Request) {
	backendAlive := checkBackend()

	if backendAlive {
		proxyRequest(w, r)
		return
	}

	// 后端不可访问
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	io.WriteString(w, initHTMLPage())
}

func checkBackend() bool {
	client := http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(fmt.Sprintf("http://%s:%s/", backendHost, backendPort))
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode == 200
}

func apiCheckBackend(w http.ResponseWriter, r *http.Request) {
	if checkBackend() {
		w.Write([]byte("true"))
	} else {
		w.Write([]byte("false"))
	}
}

func apiScriptOutput(w http.ResponseWriter, r *http.Request) {
	outputMutex.RLock()
	defer outputMutex.RUnlock()
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Write(scriptOutput.Bytes())
}

func proxyRequest(w http.ResponseWriter, r *http.Request) {
	target, _ := url.Parse(fmt.Sprintf("http://%s:%s", backendHost, backendPort))
	proxy := httputil.NewSingleHostReverseProxy(target)

	// 保证 path 和 query 都能被正确转发
	originalDirector := proxy.Director
	proxy.Director = func(req *http.Request) {
		originalDirector(req)
		// 保证 Host 头正确
		req.Host = target.Host
		// 关键：保留原始 path 和 query
		req.URL.Path = r.URL.Path
		req.URL.RawPath = r.URL.RawPath
		req.URL.RawQuery = r.URL.RawQuery
	}

	proxy.ServeHTTP(w, r)
}

func initHTMLPage() string {
	title := "程序初始化中"
	showNote := false
	if _, err := os.Stat(kvmImagePath); err == nil {
		title = "程序启动中"
	} else {
		showNote = true
	}
	noteHTML := ""
	if showNote {
		noteHTML = `<div style="color:#888;margin-top:12px;font-size:15px;">
  看到 Welcome to Home Assistant 字样后，还需等待大概 10 -- 15 分钟完成系统初始化
</div>`
	}
	return fmt.Sprintf(`
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <title>%s</title>
  <style>
    body {
      font-family: "Segoe UI", sans-serif;
      background: #f5f7fa;
      color: #333;
      text-align: center;
      padding-top: 5%%;
    }
    .container {
      max-width: 700px;
      margin: 0 auto;
    }
    .title {
      font-size: 24px;
      margin-bottom: 20px;
    }
    .progress-bar {
      position: relative;
      width: 100%%;
      height: 24px;
      background: #e0e0e0;
      border-radius: 12px;
      overflow: hidden;
    }
    .progress-bar-fill {
      position: absolute;
      height: 100%%;
      width: 30%%;
      background: linear-gradient(90deg, #4caf50 40%%, #8bc34a 100%%);
      animation: moveBar 1.2s linear infinite;
    }
    @keyframes moveBar {
      0%% { left: -30%%; }
      100%% { left: 100%%; }
    }
    textarea {
      width: 100%%;
      height: 300px;
      margin-top: 24px;
      font-family: monospace;
      font-size: 14px;
      background: #222;
      color: #b9f;
      border-radius: 8px;
      border: 1px solid #888;
      resize: vertical;
      padding: 8px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="title">%s，请稍候…</div>
    <div class="progress-bar">
      <div class="progress-bar-fill" id="progress"></div>
    </div>
    <textarea id="output" readonly></textarea>
    %s
  </div>

  <script>
    // 每 10 秒获取脚本输出
    setInterval(() => {
      fetch('/api/script_output').then(r => r.text()).then(txt => {
        const output = document.getElementById('output');
        output.value = txt;
        output.scrollTop = output.scrollHeight;
      });
    }, 10000);

    // 每 15 秒检测后端
    setInterval(() => {
      fetch('/api/check_backend').then(r => r.text()).then(ok => {
        if (ok.trim() === "true") {
          location.reload();
        }
      });
    }, 15000);
  </script>
</body>
</html>
`, title, title, noteHTML)
}
