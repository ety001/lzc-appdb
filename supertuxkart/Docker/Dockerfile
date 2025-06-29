FROM ety001/xpra-base:ubuntu-noble
RUN sudo apt-get update && \
    sudo apt-get install -y supertuxkart && \
    sudo rm -rfv /var/lib/apt/lists/*

ADD ./start_xpra.sh /usr/local/bin/start_xpra.sh
ADD ./ibus-restart.desktop /usr/share/applications/ibus-restart.desktop
ADD ./xpra.conf /etc/supervisor/conf.d/xpra.conf
