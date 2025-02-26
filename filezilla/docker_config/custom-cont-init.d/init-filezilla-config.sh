#!/bin/bash
find /etc/s6-overlay/s6-rc.d/ -name "run" -type f -print0 | while IFS= read -r -d '' file; do echo ${file}; sed -i 's/abc/root/g' "${file}"; done

mkdir -p /config/.config/filezilla
[ ! -f /config/.config/filezilla/filezilla.xml ] && cp /lzcapp/pkg/content/filezilla.xml /config/.config/filezilla/filezilla.xml
sed -i "s/LZC_USER_NAME/${LAZYCAT_APP_DEPLOY_UID}/g" /config/.config/filezilla/filezilla.xml