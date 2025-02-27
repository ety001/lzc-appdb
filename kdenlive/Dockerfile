FROM lscr.io/linuxserver/kdenlive:latest

RUN apt-get update && apt-get install -y fonts-noto-cjk
ENV TZ=Asia/Shanghai
ENV LC_ALL=zh_CN.UTF-8
#ENV LSIO_NON_ROOT_USER=1
#RUN ["bash", "-c", "find /etc/s6-overlay/s6-rc.d/ -name 'run' -type f -print0 | while IFS= read -r -d '' file; do echo ${file}; sed -i 's/abc/root/g' \"${file}\"; done"]
ADD ./docker_config /