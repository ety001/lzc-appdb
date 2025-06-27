#!/bin/bash

export LIBVA_DRIVER_NAME=iHD
export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri/
export XDG_RUNTIME_DIR=/run/user/1001
mkdir -p "${XDG_RUNTIME_DIR}"
sudo chown -R lzc:lzc "${XDG_RUNTIME_DIR}"
sudo chmod 0700 "${XDG_RUNTIME_DIR}"

export IBUS_ENABLE_SYNC_MODE=1
export GTK_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export QT_IM_MODULE=ibus
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus

main_program="/usr/bin/brave-browser --no-sandbox"
im_program="/usr/bin/ibus-daemon --xim --replace --verbose"

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
  --start="${main_program}" \
  --start="${im_program}"