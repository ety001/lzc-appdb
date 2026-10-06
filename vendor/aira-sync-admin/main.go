// aira-sync-admin: Go sidecar for Aira Personal Server.
// Serves an admin web UI (pairing codes + device management) and reverse-proxies
// the sync API to the upstream Node server.
package main

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

var (
	dbPath     = envOr("AIRA_ADMIN_DB", "/data/aira-personal-server.db")
	setupPath  = envOr("AIRA_ADMIN_SETUP_CODE", "/data/setup-code")
	upstream   = envOr("AIRA_ADMIN_UPSTREAM", "http://aira-server:8787")
	listenAddr = envOr("AIRA_ADMIN_LISTEN", "0.0.0.0:8080")
	adminToken = os.Getenv("AIRA_ADMIN_TOKEN")
	sessionKey []byte
)

func envOr(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

// ---- upstream-compatible helpers ----

// mintCode generates a pairing code exactly like upstream instance.js
// createReadableCode(): 18 random bytes -> base64url -> uppercase (24 chars).
func mintCode() string {
	b := make([]byte, 18)
	if _, err := rand.Read(b); err != nil {
		log.Fatalf("rand: %v", err)
	}
	return strings.ToUpper(base64.RawURLEncoding.EncodeToString(b))
}

func hashSecret(v string) string {
	sum := sha256.Sum256([]byte(v))
	return hex.EncodeToString(sum[:])
}

// ---- session (HMAC cookie) ----

func signSession(expires int64) string {
	m := hmac.New(sha256.New, sessionKey)
	fmt.Fprintf(m, "%d", expires)
	return hex.EncodeToString(m.Sum(nil))
}

func validSession(r *http.Request) bool {
	c, err := r.Cookie("aira_admin_session")
	if err != nil {
		return false
	}
	parts := strings.SplitN(c.Value, ":", 2)
	if len(parts) != 2 {
		return false
	}
	exp, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil || exp < time.Now().Unix() || exp > time.Now().Unix()+25*3600 {
		return false
	}
	return hmac.Equal([]byte(parts[1]), []byte(signSession(exp)))
}

func setSession(w http.ResponseWriter) {
	exp := time.Now().Add(12 * time.Hour).Unix()
	http.SetCookie(w, &http.Cookie{
		Name:     "aira_admin_session",
		Value:    fmt.Sprintf("%d:%s", exp, signSession(exp)),
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
	})
}

func clearSession(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{Name: "aira_admin_session", Value: "", Path: "/", MaxAge: -1, HttpOnly: true})
}

// ---- db helpers ----

func openDB() *sql.DB {
	d, err := sql.Open("sqlite", dbPath+"?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)&_pragma=foreign_keys(1)")
	if err != nil {
		log.Fatalf("open db: %v", err)
	}
	d.SetMaxOpenConns(1)
	return d
}

type Device struct {
	ID         string  `json:"id"`
	Name       string  `json:"name"`
	Kind       string  `json:"kind"`
	CreatedAt  int64   `json:"createdAt"`
	LastSeenAt int64   `json:"lastSeenAt"`
	RotatedAt  int64   `json:"rotatedAt"`
	RevokedAt  int64   `json:"revokedAt"`
	Online     bool    `json:"online"`
}

type CodeRow struct {
	Kind        string `json:"kind"`
	CreatedBy   string `json:"createdBy"`
	CreatedAt   int64  `json:"createdAt"`
	ExpiresAt   int64  `json:"expiresAt"`
	Used        bool   `json:"used"`
	Expired     bool   `json:"expired"`
	IsBootstrap bool   `json:"isBootstrap"`
}

func listDevices(db *sql.DB) []Device {
	rows, err := db.Query(`SELECT device_id, name, device_kind, created_at, last_seen_at, rotated_at, revoked_at FROM devices ORDER BY created_at ASC`)
	if err != nil {
		log.Printf("listDevices: %v", err)
		return nil
	}
	defer rows.Close()
	now := time.Now().UnixMilli()
	var out []Device
	for rows.Next() {
		var d Device
		if err := rows.Scan(&d.ID, &d.Name, &d.Kind, &d.CreatedAt, &d.LastSeenAt, &d.RotatedAt, &d.RevokedAt); err != nil {
			continue
		}
		d.Online = d.RevokedAt == 0 && now-d.LastSeenAt < 10*60*1000
		out = append(out, d)
	}
	return out
}

func listCodes(db *sql.DB, limit int) []CodeRow {
	rows, err := db.Query(`SELECT kind, created_by_device_id, created_at, expires_at, used_at FROM pairing_codes ORDER BY created_at DESC LIMIT ?`, limit)
	if err != nil {
		return nil
	}
	defer rows.Close()
	now := time.Now().UnixMilli()
	var out []CodeRow
	for rows.Next() {
		var c CodeRow
		var used int64
		if err := rows.Scan(&c.Kind, &c.CreatedBy, &c.CreatedAt, &c.ExpiresAt, &used); err != nil {
			continue
		}
		c.Used = used != 0
		c.Expired = !c.Used && c.ExpiresAt < now
		c.IsBootstrap = c.Kind == "bootstrap"
		out = append(out, c)
	}
	return out
}

// bootstrapStatus reads /data/setup-code if present, looks up its hash in the DB.
// Returns plaintext + validity.
func bootstrapStatus(db *sql.DB) (code string, valid bool, status string) {
	raw, err := os.ReadFile(setupPath)
	if err != nil {
		return "", false, "unavailable"
	}
	code = strings.TrimSpace(string(raw))
	var used, expires int64
	err = db.QueryRow(`SELECT used_at, expires_at FROM pairing_codes WHERE code_hash = ?`, hashSecret(code)).Scan(&used, &expires)
	if err == sql.ErrNoRows {
		return code, false, "consumed"
	}
	if err != nil {
		return code, false, "error"
	}
	if used != 0 {
		return code, false, "consumed"
	}
	if expires < time.Now().UnixMilli() {
		return code, false, "expired"
	}
	return code, true, "valid"
}

func mintPairingCode(db *sql.DB, ttl time.Duration) (string, int64, error) {
	code := mintCode()
	now := time.Now().UnixMilli()
	exp := now + ttl.Milliseconds()
	_, err := db.Exec(`INSERT INTO pairing_codes(code_hash, kind, created_by_device_id, created_at, expires_at, used_at) VALUES(?, 'device', 'admin-ui', ?, ?, 0)`,
		hashSecret(code), now, exp)
	return code, exp, err
}

func revokeDevice(db *sql.DB, id string) (bool, error) {
	res, err := db.Exec(`UPDATE devices SET revoked_at = ? WHERE device_id = ? AND revoked_at = 0`, time.Now().UnixMilli(), id)
	if err != nil {
		return false, err
	}
	n, _ := res.RowsAffected()
	return n == 1, nil
}

// ---- http handlers ----

var pageTpl = template.Must(template.New("page").Funcs(template.FuncMap{
	"ts": func(ms int64) string {
		if ms == 0 {
			return "-"
		}
		return time.UnixMilli(ms).Format("2006-01-02 15:04")
	},
}).Parse(pageHTML))
var loginTpl = template.Must(template.New("login").Parse(loginHTML))

type PageData struct {
	InstanceID    string
	InstanceSince string
	SetupCode     string
	SetupStatus   string
	SetupValid    bool
	Devices       []Device
	Codes         []CodeRow
	Flash         string
	NewCode       string
	NewCodeExp    string
	AdminURL      string
}

func renderPage(w http.ResponseWriter, d PageData) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	if err := pageTpl.Execute(w, d); err != nil {
		log.Printf("template: %v", err)
	}
}

func handleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		loginTpl.Execute(w, map[string]string{"Error": ""})
		return
	}
	if err := r.ParseForm(); err != nil {
		w.WriteHeader(400)
		return
	}
	if hmac.Equal([]byte(r.FormValue("token")), []byte(adminToken)) {
		setSession(w)
		http.Redirect(w, r, "/admin", http.StatusSeeOther)
		return
	}
	time.Sleep(300 * time.Millisecond)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	loginTpl.Execute(w, map[string]string{"Error": "令牌不正确"})
}

func requireAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if adminToken == "" || !validSession(r) {
			http.Redirect(w, r, "/admin/login", http.StatusSeeOther)
			return
		}
		next(w, r)
	}
}

func makeAdminHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var d PageData
		var instanceID string
		var createdAt int64
		if err := db.QueryRow(`SELECT instance_id, created_at FROM instance_meta WHERE singleton = 1`).Scan(&instanceID, &createdAt); err == nil {
			d.InstanceID = instanceID
			d.InstanceSince = time.UnixMilli(createdAt).Format("2006-01-02 15:04")
		}
		code, valid, status := bootstrapStatus(db)
		d.SetupCode, d.SetupValid, d.SetupStatus = code, valid, status
		d.Devices = listDevices(db)
		d.Codes = listCodes(db, 30)

		flash := r.URL.Query().Get("flash")
		if flash == "revoked" {
			d.Flash = "设备已吊销"
		}
		if flash == "minted" {
			d.NewCode = r.URL.Query().Get("code")
			d.NewCodeExp = r.URL.Query().Get("exp")
		}
		if flash == "err" {
			d.Flash = "操作失败，请重试"
		}
		renderPage(w, d)
	}
}

func makeMintHandler(db *sql.DB) http.HandlerFunc {
	return requireAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/admin", http.StatusSeeOther)
			return
		}
		ttl := 10 * time.Minute
		if v := r.FormValue("ttl"); v != "" {
			if n, err := strconv.Atoi(v); err == nil && n >= 1 && n <= 1440 {
				ttl = time.Duration(n) * time.Minute
			}
		}
		code, exp, err := mintPairingCode(db, ttl)
		if err != nil {
			log.Printf("mint: %v", err)
			http.Redirect(w, r, "/admin?flash=err", http.StatusSeeOther)
			return
		}
		http.Redirect(w, r, fmt.Sprintf("/admin?flash=minted&code=%s&exp=%s", code, time.UnixMilli(exp).Format("15:04:05")), http.StatusSeeOther)
	})
}

func makeRevokeHandler(db *sql.DB) http.HandlerFunc {
	return requireAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/admin", http.StatusSeeOther)
			return
		}
		id := r.PathValue("id")
		ok, err := revokeDevice(db, id)
		if err != nil || !ok {
			log.Printf("revoke %s: ok=%v err=%v", id, ok, err)
			http.Redirect(w, r, "/admin?flash=err", http.StatusSeeOther)
			return
		}
		http.Redirect(w, r, "/admin?flash=revoked", http.StatusSeeOther)
	})
}

func makeAPIHandler(db *sql.DB) http.HandlerFunc {
	return requireAuth(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		json.NewEncoder(w).Encode(map[string]any{
			"ok":      true,
			"devices": listDevices(db),
			"codes":   listCodes(db, 50),
		})
	})
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "-healthcheck" {
		check := func(addr string) bool {
			client := http.Client{Timeout: 3 * time.Second}
			resp, err := client.Get("http://" + addr + "/admin/login")
			if err != nil {
				return false
			}
			resp.Body.Close()
			return resp.StatusCode == http.StatusOK
		}
		host, port, _ := net.SplitHostPort(listenAddr)
		if host == "" || host == "0.0.0.0" || host == "::" {
			host = "127.0.0.1"
		}
		if !check(net.JoinHostPort(host, port)) {
			os.Exit(1)
		}
		return
	}
	if t := strings.TrimSpace(adminToken); t == "" || t == "<no value>" {
		log.Fatalf("AIRA_ADMIN_TOKEN is required: set the admin_token deploy param on the LazyCat setup wizard (required field), then reinstall. Refusing to generate a token automatically.")
	}
	key := sha256.Sum256([]byte("aira-admin-session:" + adminToken))
	sessionKey = key[:]

	db := openDB()
	defer db.Close()

	up, err := url.Parse(upstream)
	if err != nil {
		log.Fatalf("upstream url: %v", err)
	}
	proxy := httputil.NewSingleHostReverseProxy(up)
	origDirector := proxy.Director
	proxy.Director = func(req *http.Request) {
		origDirector(req)
		req.Host = up.Host
	}
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Printf("proxy %s: %v", r.URL.Path, err)
		w.WriteHeader(http.StatusBadGateway)
		w.Write([]byte(`{"ok":false,"code":"upstream_unavailable","message":"同步服务暂不可用"}`))
	}

	mux := http.NewServeMux()

	// admin UI
	mux.HandleFunc("GET /admin/login", handleLogin)
	mux.HandleFunc("POST /admin/login", handleLogin)
	mux.HandleFunc("POST /admin/logout", func(w http.ResponseWriter, r *http.Request) {
		clearSession(w)
		http.Redirect(w, r, "/admin/login", http.StatusSeeOther)
	})
	mux.Handle("GET /admin", requireAuth(makeAdminHandler(db)))
	mux.Handle("POST /admin/codes", makeMintHandler(db))
	mux.Handle("POST /admin/devices/{id}/revoke", makeRevokeHandler(db))
	mux.Handle("GET /admin/api/status", makeAPIHandler(db))

	// root: "/" redirects to admin, everything else proxies to the sync server.
	// 注意不能写 "GET /" —— Go 1.22 method pattern 会把 POST 落到内置 405，
	// 同步客户端全部用 POST，必须匹配所有方法。
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/" {
			http.Redirect(w, r, "/admin", http.StatusFound)
			return
		}
		proxy.ServeHTTP(w, r)
	})

	srv := &http.Server{
		Addr:              listenAddr,
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
	}
	log.Printf("aira-sync-admin listening on %s (upstream %s, db %s)", listenAddr, upstream, dbPath)
	ctx, cancel := context.WithTimeout(context.Background(), 0)
	defer cancel()
	_ = ctx
	if err := srv.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}
