#!/bin/bash

envfile="/config/envfile.txt"

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

/jellyfin/jellyfin