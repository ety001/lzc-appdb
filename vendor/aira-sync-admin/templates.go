package main

// Templates are defined as raw string constants so the binary stays self-contained
// (no external template files to mount in the container).

const loginHTML = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>登录 · Aira 同步管理</title>
<style>
  body { font-family:-apple-system,"Noto Sans SC",sans-serif; background:#f5f6f8; display:flex; justify-content:center; align-items:center; min-height:100vh; margin:0; }
  .box { background:#fff; border:1px solid #e5e7eb; border-radius:12px; padding:32px; width:min(360px, 90vw); }
  h1 { font-size:18px; margin:0 0 6px; }
  p { color:#6b7280; font-size:13px; margin:0 0 18px; }
  input { width:100%; padding:10px 12px; border:1px solid #d1d5db; border-radius:8px; font-size:14px; margin-bottom:12px; box-sizing:border-box; }
  button { width:100%; padding:10px; background:#2563eb; color:#fff; border:none; border-radius:8px; font-size:14px; cursor:pointer; }
  .err { color:#dc2626; font-size:13px; margin-bottom:10px; }
</style>
</head>
<body>
<div class="box">
  <h1>Aira 同步服务器管理</h1>
  <p>请输入管理令牌</p>
  {{if .Error}}<div class="err">{{.Error}}</div>{{end}}
  <form method="post">
    <input type="password" name="token" placeholder="管理令牌" autofocus autocomplete="current-password">
    <button type="submit">登录</button>
  </form>
</div>
</body>
</html>`

// pageHTML uses a ts template function injected at parse time.
const pageHTML = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Aira 同步服务器管理</title>
<style>
  :root { --bg:#f5f6f8; --card:#fff; --ink:#1c1e21; --muted:#6b7280; --line:#e5e7eb; --brand:#2563eb; --ok:#059669; }
  * { box-sizing:border-box; margin:0; }
  body { font-family:-apple-system,"Noto Sans SC","PingFang SC","Microsoft YaHei",sans-serif; background:var(--bg); color:var(--ink); padding:24px 16px 64px; }
  .wrap { max-width:880px; margin:0 auto; }
  header { display:flex; align-items:center; justify-content:space-between; margin-bottom:20px; flex-wrap:wrap; gap:8px; }
  h1 { font-size:20px; }
  h1 small { color:var(--muted); font-weight:400; font-size:13px; margin-left:8px; }
  .card { background:var(--card); border:1px solid var(--line); border-radius:12px; padding:18px 20px; margin-bottom:16px; }
  .card h2 { font-size:15px; margin-bottom:12px; }
  .row { display:flex; gap:10px; flex-wrap:wrap; align-items:center; }
  .kv { font-size:13px; color:var(--muted); }
  code.big { font-size:22px; letter-spacing:2px; background:#eef2ff; color:#1e3a8a; padding:8px 14px; border-radius:8px; font-family:ui-monospace,Menlo,Consolas,monospace; user-select:all; }
  .badge { display:inline-block; font-size:12px; padding:2px 10px; border-radius:999px; }
  .b-ok { background:#d1fae5; color:#065f46; }
  .b-muted { background:#f3f4f6; color:#6b7280; }
  .b-bad { background:#fee2e2; color:#991b1b; }
  table { width:100%; border-collapse:collapse; font-size:13.5px; }
  th { text-align:left; color:var(--muted); font-weight:500; font-size:12.5px; padding:6px 8px; border-bottom:1px solid var(--line); }
  td { padding:8px; border-bottom:1px solid #f3f4f6; vertical-align:top; }
  tr:last-child td { border-bottom:none; }
  button { border:none; border-radius:8px; padding:8px 14px; font-size:13.5px; cursor:pointer; }
  .btn { background:var(--brand); color:#fff; }
  .btn-danger { background:#fee2e2; color:#991b1b; }
  .btn-ghost { background:transparent; color:var(--muted); padding:8px 4px; }
  button:hover { filter:brightness(.95); }
  .newcode { background:#ecfdf5; border:1px solid #a7f3d0; }
  .flash { background:#eff6ff; border:1px solid #bfdbfe; color:#1e40af; padding:10px 14px; border-radius:8px; margin-bottom:14px; font-size:14px; }
  .empty { color:var(--muted); font-size:13px; padding:12px 0; }
  select { padding:8px; border-radius:8px; border:1px solid var(--line); font-size:13.5px; }
  footer { text-align:center; color:var(--muted); font-size:12px; margin-top:28px; }
</style>
</head>
<body>
<div class="wrap">
  <header>
    <h1>Aira 同步服务器<small>{{.InstanceID}}</small></h1>
    <form method="post" action="/admin/logout"><button class="btn-ghost" type="submit">退出</button></form>
  </header>

  {{if .Flash}}<div class="flash">{{.Flash}}</div>{{end}}

  {{if .NewCode}}
  <div class="card newcode">
    <h2>✅ 新配对码已生成</h2>
    <div class="row" style="margin-bottom:8px">
      <code class="big">{{.NewCode}}</code>
    </div>
    <div class="kv">{{.NewCodeExp}} 到期 · 仅可使用一次 · 在设备配对页填入</div>
  </div>
  {{end}}

  <div class="card">
    <h2>初始配对码（setup-code）</h2>
    {{if .SetupValid}}
      <div class="row" style="margin-bottom:8px"><code class="big">{{.SetupCode}}</code></div>
      <div class="kv">首台设备配对后自动失效（24 小时有效）</div>
    {{else if eq .SetupStatus "consumed"}}
      <div class="empty">初始配对码已被使用。用下方按钮为新设备签发新配对码。</div>
    {{else if eq .SetupStatus "expired"}}
      <div class="empty">初始配对码已过期。用下方按钮为新设备签发新配对码。</div>
    {{else}}
      <div class="empty">初始配对码不存在（已用或未生成）。用下方按钮为新设备签发新配对码。</div>
    {{end}}
  </div>

  <div class="card">
    <h2>签发新配对码</h2>
    <form method="post" action="/admin/codes" class="row">
      <select name="ttl">
        <option value="10">10 分钟（默认）</option>
        <option value="30">30 分钟</option>
        <option value="60">1 小时</option>
        <option value="1440">24 小时</option>
      </select>
      <button class="btn" type="submit">生成配对码</button>
    </form>
    <div class="kv" style="margin-top:8px">生成后立即显示一次，页面刷新即无法找回（数据库只存哈希）。请当场抄下或复制。</div>
  </div>

  <div class="card">
    <h2>已配对设备</h2>
    {{if .Devices}}
    <table>
      <tr><th>设备</th><th>类型</th><th>状态</th><th>最近在线</th><th></th></tr>
      {{range .Devices}}
      <tr>
        <td><b>{{.Name}}</b><br><span class="kv">{{.ID}}</span></td>
        <td>{{if eq .Kind "desktop"}}电脑{{else}}手机{{end}}</td>
        <td>
          {{if ne .RevokedAt 0}}<span class="badge b-bad">已吊销</span>
          {{else if .Online}}<span class="badge b-ok">在线</span>
          {{else}}<span class="badge b-muted">离线</span>{{end}}
        </td>
        <td>{{if .LastSeenAt}}{{ts .LastSeenAt}}{{else}}-{{end}}</td>
        <td>
          {{if eq .RevokedAt 0}}
          <form method="post" action="/admin/devices/{{.ID}}/revoke" onsubmit="return confirm('吊销后该设备立即失去同步权限（不影响设备本地数据）。确定吊销？')">
            <button class="btn-danger" type="submit">吊销</button>
          </form>
          {{end}}
        </td>
      </tr>
      {{end}}
    </table>
    {{else}}
    <div class="empty">还没有设备配对。用上面的初始配对码或新配对码连接第一台设备。</div>
    {{end}}
  </div>

  <div class="card">
    <h2>配对码记录（最近 30 条）</h2>
    {{if .Codes}}
    <table>
      <tr><th>类型</th><th>来源</th><th>创建时间</th><th>过期时间</th><th>状态</th></tr>
      {{range .Codes}}
      <tr>
        <td>{{if .IsBootstrap}}初始码{{else}}设备签发{{end}}</td>
        <td class="kv">{{if .CreatedBy}}{{.CreatedBy}}{{else}}-{{end}}</td>
        <td>{{ts .CreatedAt}}</td>
        <td>{{ts .ExpiresAt}}</td>
        <td>
          {{if .Used}}<span class="badge b-muted">已使用</span>
          {{else if .Expired}}<span class="badge b-bad">已过期</span>
          {{else}}<span class="badge b-ok">有效</span>{{end}}
        </td>
      </tr>
      {{end}}
    </table>
    {{else}}
    <div class="empty">暂无记录</div>
    {{end}}
    <div class="kv" style="margin-top:8px">配对码原文只显示一次，服务端只保留 SHA-256 哈希。</div>
  </div>

  <footer>实例创建于 {{.InstanceSince}} · 数据与同步服务共库（只读 + 配对码写入）</footer>
</div>
</body>
</html>`
