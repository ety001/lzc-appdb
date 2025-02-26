#!/bin/bash
mkdir -p /config/.config/filezilla
[ ! -f /config/.config/filezilla/filezilla.xml ] && cp /lzcapp/pkg/content/filezilla.xml /config/.config/filezilla/filezilla.xml
sed -i "s/LZC_USER_NAME/${LAZYCAT_APP_DEPLOY_UID}/g" /config/.config/filezilla/filezilla.xml