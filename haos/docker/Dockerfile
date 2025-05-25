FROM debian:bookworm-slim

RUN apt update && \
    apt upgrade -y && \
    apt install -y qemu-system-x86 ovmf \
                    vim xz-utils \
                    net-tools iproute2 && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

ADD run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]