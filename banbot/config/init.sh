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
            # set env
            export "$key"="$value"
        fi
    done < "$envfile"
else
    echo "$envfile not exist, pass this part."
fi
/ban/bot -config /config/config.yml -host 0.0.0.0

# 定义重试次数和间隔时间
#x=10  # 重试次数
#y=10  # 间隔时间（秒）
#
#attempt=0
#while [ $attempt -lt $x ]; do
#  /ban/bot -config /config/config.yml -host 0.0.0.0
#  exit_status=$?
#  if [ $exit_status -eq 0 ]; then
#    # 程序成功执行，退出循环
#    break
#  else
#    attempt=$((attempt + 1))
#    if [ $attempt -lt $x ]; then
#      echo "程序执行失败，将在 $y 秒后进行第 $attempt 次重试..."
#      sleep $y
#    fi
#  fi
#done
#
#if [ $attempt -eq $x ]; then
#  echo "程序经过 $x 次重试后仍然失败。"
#fi