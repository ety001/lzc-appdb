#!/bin/bash
[ ! -f /config/.config/kdenliverc ] && cp /lzcapp/pkg/content/kdenliverc /config/.config/kdenliverc
sed -i "s/LZC_USER_NAME/${LAZYCAT_APP_DEPLOY_UID}/g" /config/.config/kdenliverc
[ ! -f /config/.config/QtProject.conf ] && cp /lzcapp/pkg/content/QtProject.conf /config/.config/QtProject.conf
sed -i "s/LZC_USER_NAME/${LAZYCAT_APP_DEPLOY_UID}/g" /config/.config/QtProject.conf