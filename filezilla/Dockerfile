FROM lscr.io/linuxserver/filezilla:latest

RUN apk add --no-cache font-noto-cjk
ENV TZ=Asia/Shanghai
ENV LC_ALL=zh_CN.UTF-8

COPY ./config/run /etc/s6-overlay/s6-rc.d/init-os-end/