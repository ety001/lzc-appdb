FROM debian:bookworm-slim

ARG REPOFILE=https://raw.githubusercontent.com/Xpra-org/xpra/master/packaging/repos/bookworm/xpra-lts.sources

RUN apt update && \
    apt upgrade -y && \
    apt install -y ca-certificates && \
    wget -O "/usr/share/keyrings/xpra.asc" https://xpra.org/xpra.asc && \
    cd /etc/apt/sources.list.d && wget $REPOFILE && \
    apt update && apt install xorg-server xpra
