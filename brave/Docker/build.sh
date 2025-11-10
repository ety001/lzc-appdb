#!/bin/bash

docker build --push \
    -t ety001/brave-browser:ubuntu-noble \
    -f Dockerfile .
