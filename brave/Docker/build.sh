#!/bin/bash

docker build --push \
    --build-arg HTTPS_PROXY=http://192.168.199.11:8001 \
    -t ety001/brave-browser:ubuntu-noble \
    -f Dockerfile .
