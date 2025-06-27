FROM ety001/xpra-base:ubuntu-noble

RUN curl -fsSLo ~/obsidian.deb https://github.com/obsidianmd/obsidian-releases/releases/download/v1.8.10/obsidian_1.8.10_amd64.deb && \
    sudo apt update && sudo apt install -y libsecret-1-0 && \
    sudo dpkg -i --force-confdef --force-confold ~/obsidian.deb
    
RUN sudo sed -i 's|^\(Exec=/opt/Obsidian/obsidian\)\(.*\)|\1 --no-sandbox\2|' /usr/share/applications/obsidian.desktop

ADD ./start_xpra.sh /usr/local/bin/start_xpra.sh
ADD ./ibus-restart.desktop /usr/share/applications/ibus-restart.desktop
ADD ./xpra.conf /etc/supervisor/conf.d/xpra.conf
