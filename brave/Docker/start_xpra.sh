#!/bin/bash

export LIBVA_DRIVER_NAME=iHD
export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri/
export XDG_RUNTIME_DIR=/dev/shm/run/user/1001
mkdir -p "${XDG_RUNTIME_DIR}"
sudo chown -R lzc:lzc "${XDG_RUNTIME_DIR}"
sudo chmod 0700 "${XDG_RUNTIME_DIR}"

main_program="/usr/bin/brave-browser --no-sandbox --start-maximized"

exec xpra start :100 \
  --daemon=no \
  --opengl=yes \
  --encoding=h264 \
  --video-encoders=vaapi \
  --dpi=96 \
  --quality=40 \
  --speed=50 \
  --html=on \
  --bind-tcp=0.0.0.0:10000 \
  --webcam=no \
  --start="${main_program}"