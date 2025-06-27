FROM ety001/xpra-base:ubuntu-noble

RUN curl -fsSLo ~/obsidian.deb https://github.com/obsidianmd/obsidian-releases/releases/download/v1.8.10/obsidian_1.8.10_amd64.deb && \
    sudo apt update && sudo apt install -y libsecret-1-0 && \
    sudo dpkg -i --force-confdef --force-confold ~/obsidian.deb

ADD ./start_xpra.sh /usr/local/bin/start_xpra.sh
ADD ./xpra.conf /etc/supervisor/conf.d/xpra.conf
