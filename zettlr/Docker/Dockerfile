FROM ety001/xpra-base:ubuntu-noble

RUN wget https://github.com/Zettlr/Zettlr/releases/download/v3.5.1/Zettlr-3.5.1-amd64.deb && \
    sudo dpkg -i Zettlr-3.5.1-amd64.deb && \
    rm -rf Zettlr-3.5.1-amd64.deb
    
ADD ./zettlr.desktop /usr/share/applications/zettlr.desktop
ADD ./start_xpra.sh /usr/local/bin/start_xpra.sh
ADD ./ibus-restart.desktop /usr/share/applications/ibus-restart.desktop
ADD ./xpra.conf /etc/supervisor/conf.d/xpra.conf
