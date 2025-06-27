FROM ety001/xpra-base:ubuntu-noble
RUN sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list && \
    sudo apt-get update && \
    sudo apt-get install -y brave-browser && \
    sudo rm -rfv /var/lib/apt/lists/* && \
    sudo sed -i 's|^\(Exec=/usr/bin/brave-browser-stable\)\(.*\)|\1 --no-sandbox\2|' /usr/share/applications/brave-browser.desktop

ADD ./start_xpra.sh /usr/local/bin/start_xpra.sh
ADD ./start_ibus.sh /usr/local/bin/start_ibus.sh
ADD ./xpra.conf /etc/supervisor/conf.d/xpra.conf
