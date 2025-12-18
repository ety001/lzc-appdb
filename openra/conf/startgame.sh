#!/bin/bash

program=/usr/games/openra-ra

xpra start :100 \
  --start-child=${program} \
  --env=DISPLAY_RESOLUTION=1280x720 \
  --daemon=no \
  --opengl=yes \
  --encoding=h264 \
  --video-encoders=vaapi \
  --quality=50 \
  --speed=30 \
  --compressors=lz4 \
  --dpi=96 \
  --clipboard=no \
  --pulseaudio=no \
  --notifications=no \
  --min-quality=40 \
  --min-speed=30 \
  --env=XPRA_DISABLE_AUDIO=1