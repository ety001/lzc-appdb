FROM ety001/xpra-base:ubuntu-noble

RUN curl -fsS https://dl.brave.com/install.sh | sh && \
    sudo rm -rfv /var/lib/apt/lists/*

RUN sudo sed -i 's|^\(Exec=/usr/bin/brave-browser-stable\)\(.*\)|\1 --no-sandbox\2|' /usr/share/applications/brave-browser.desktop

ADD ./start_xpra.sh /usr/local/bin/start_xpra.sh
ADD ./ibus-restart.desktop /usr/share/applications/ibus-restart.desktop
ADD ./xpra.conf /etc/supervisor/conf.d/xpra.conf
