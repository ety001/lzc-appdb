#!/bin/bash

program="/usr/bin/brave-browser --no-sandbox"

exec xpra start :100 \
  --daemon=no \
  --opengl=yes \
  --encoding=h264 \
  --video-encoders=vaapi \
  --compressors=lz4 \
  --dpi=96 \
  --quality=20 \
  --speed=30 \
  --html=on \
  --bind-tcp=0.0.0.0:10000 \
  --webcam=no \
  --start-child="${program}"