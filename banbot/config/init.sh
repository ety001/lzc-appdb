#!/bin/bash
if [ ! -f "/config/config.yml" ]; then
  cp /lzcapp/pkg/content/init.yml /config/config.yml
  #sed -i "s/datahost/timescaledb.${LAZYCAT_APP_ID}.lzcapp/g" /config/config.yml
  sed -i "s/datahost/timescaledb/g" /config/config.yml
fi

envfile="/config/envfile"

# check if file exists
if [ -f "$envfile" ]; then
    # read file line by line
    while IFS= read -r line; do
        # ignore empty line and comment line
        if [[ -n "$line" && ! "$line" =~ ^# ]]; then
            # parse key and value
            key=$(echo "$line" | cut -d'=' -f1)
            value=$(echo "$line" | cut -d'=' -f2)
            echo "TEST ENV: $key=$value"
            # set env
            export "$key"="$value"
        fi
    done < "$envfile"
else
    echo "$envfile not exist, pass this part."
fi

# config retry times
retry=20  # retry times
interval=10  # interval (seconds)

attempt=0
while [ $attempt -lt $retry ]; do
  /ban/bot -config /config/config.yml -host 0.0.0.0
  exit_status=$?
  if [ $exit_status -eq 0 ]; then
    # do success and exit loop
    break
  else
    attempt=$((attempt + 1))
    if [ $attempt -lt $retry ]; then
      echo "程序执行失败，将在 $y 秒后进行第 $attempt 次重试..."
      sleep $interval
    fi
  fi
done

if [ $attempt -eq $retry ]; then
  echo "程序经过 $retry 次重试后仍然失败。"
fi