#FROM ety001/xpra-base:latest
FROM ety001/xpra-base:ubuntu-noble

RUN sudo apt update -y && \
    sudo apt install -y supertuxkart && \
    sudo apt clean && \
    sudo rm -rf /var/lib/apt/lists/*

EXPOSE 10000
