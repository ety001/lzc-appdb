#!/bin/bash

# 检查/ban/strats 目录是否为空
mkdir -p /ban/strats
if [ -z "$(ls -A /ban/strats)" ]; then
    echo "Directory /ban/strats is empty, extracting files..."
    tar -xzvf /lzcapp/pkg/content/banstrats.tar.gz -C /ban/strats/
fi

# 检查/ban/data/uidist 目录是否为空
mkdir -p /ban/data/uidist
if [ -z "$(ls -A /ban/data/uidist)" ]; then
    echo "Directory /ban/data/uidist is empty, extracting files..."
    tar -xzvf /lzcapp/pkg/content/uidist.tar.gz -C /ban/data/uidist/
fi

#/ban/bot --config /lzcapp/pkg/content/init.yml

/ban/bot --config /lzcapp/pkg/content/init.yml
exit_status=$?
if [ $exit_status -ne 0 ]; then
  cp -r /lzcapp/pkg/content/error /tmp/error

  sed -i "s/UID/$LAZYCAT_APP_DEPLOY_UID/g" /tmp/error/index.html
  sed -i "s/APPID/$LAZYCAT_APP_ID/g" /tmp/error/index.html
  sed -i "s/BOXDOMAIN/$LAZYCAT_BOX_DOMAIN/g" /tmp/error/index.html

  echo "Copy error log to /tmp/error/"
  cp /ban/data/logs/ban.log /tmp/error/ban.log
  echo "Start service failed and run a temporary web server to display error page ..."
  /lzcapp/pkg/content/webserv -d /tmp/error/ -p 8000
fi
