FROM ety001/xpra-base:ubuntu-noble

RUN sudo apt update && sudo apt install -y gnupg && \
    curl -s --compressed "https://apt.zettlr.com/KEY.gpg" | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/zettlr_apt.gpg > /dev/null && \
    sudo curl -s --compressed -o /etc/apt/sources.list.d/zettlr.list "https://apt.zettlr.com/zettlr.list" && apt update && \
    apt install -y zettlr && \
    rm -rfv /var/lib/apt/lists/*
    
#ADD ./obsidian.desktop /usr/share/applications/obsidian.desktop
ADD ./start_xpra.sh /usr/local/bin/start_xpra.sh
ADD ./ibus-restart.desktop /usr/share/applications/ibus-restart.desktop
ADD ./xpra.conf /etc/supervisor/conf.d/xpra.conf
