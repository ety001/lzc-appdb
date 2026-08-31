#!/bin/bash
set -e
cd /opt/game
exec python3 -m http.server 6080 --bind 0.0.0.0
