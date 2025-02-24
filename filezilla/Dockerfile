FROM lscr.io/linuxserver/filezilla:latest

RUN apk add --no-cache font-noto-cjk && \
    sed -i 's/abc/root/g' /s6-rc.d/*
ENV TZ=Asia/Shanghai
ENV LC_ALL=zh_CN.UTF-8