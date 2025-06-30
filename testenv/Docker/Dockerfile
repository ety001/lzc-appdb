FROM ety001/xpra-base:ubuntu-noble

#RUN 
    
#RUN sudo sed -i 's|^\(Exec=/opt/Obsidian/obsidian\)\(.*\)|\1 --no-sandbox\2|' /usr/share/applications/obsidian.desktop

#ADD ./obsidian.desktop /usr/share/applications/obsidian.desktop
ADD ./start_xpra.sh /usr/local/bin/start_xpra.sh
ADD ./ibus-restart.desktop /usr/share/applications/ibus-restart.desktop
ADD ./xpra.conf /etc/supervisor/conf.d/xpra.conf
