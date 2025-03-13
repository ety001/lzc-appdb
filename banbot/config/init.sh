#!/bin/bash
if [ ! -f "/config/config.yml" ]; then
  cp /lzcapp/pkg/content/init.yml /config/config.yml
  sed -i "s/datahost/timescaledb.${LAZYCAT_APP_ID}.lzcapp/g" /config/config.yml
fi

/ban/bot -config /config/config.yml -host 0.0.0.0
