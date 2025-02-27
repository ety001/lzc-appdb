#!/bin/bash
mkdir -p /config/.config/sqlitebrowser
[ ! -f /config/.config/sqlitebrowser/sqlitebrowser.conf ] && cp /lzcapp/pkg/content/sqlitebrowser.conf /config/.config/sqlitebrowser/sqlitebrowser.conf
sed -i "s/LZC_USER_NAME/${LAZYCAT_APP_DEPLOY_UID}/g" /config/.config/sqlitebrowser/sqlitebrowser.conf
[ ! -f /config/.config/QtProject.conf ] && cp /lzcapp/pkg/content/QtProject.conf /config/.config/QtProject.conf
sed -i "s/LZC_USER_NAME/${LAZYCAT_APP_DEPLOY_UID}/g" /config/.config/QtProject.conf