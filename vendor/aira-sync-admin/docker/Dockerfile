# aira-sync-admin: Go sidecar providing an admin web UI for Aira Personal Server.
# Static binary (CGO disabled, modernc.org/sqlite pure-Go driver).
FROM golang:1.27-bookworm AS build
WORKDIR /src
ENV CGO_ENABLED=0 GOOS=linux
COPY go.mod go.sum ./
RUN go mod download
COPY main.go templates.go ./
RUN go build -trimpath -ldflags="-s -w" -o /out/aira-sync-admin .

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /out/aira-sync-admin /usr/local/bin/aira-sync-admin
ENV AIRA_ADMIN_LISTEN=0.0.0.0:8080 \
    AIRA_ADMIN_DB=/data/aira-personal-server.db \
    AIRA_ADMIN_SETUP_CODE=/data/setup-code \
    AIRA_ADMIN_UPSTREAM=http://aira-server:8787
USER 65534:65534
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD ["aira-sync-admin", "-healthcheck"]
ENTRYPOINT ["aira-sync-admin"]
