#!/bin/bash

export LIBVA_DRIVER_NAME=iHD
export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri/
export XDG_RUNTIME_DIR=/run/user/1001
export IBUS_ENABLE_SYNC_MODE=1
export GTK_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export QT_IM_MODULE=ibus
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus

main_program="/usr/bin/brave-browser-stable --no-sandbox --start-maximized"

exec xpra start :0 \
  --daemon=no \
  --opengl=yes \
  --encoding=h264 \
  --video-encoders=vaapi \
  --dpi=96 \
  --quality=50 \
  --speed=50 \
  --html=on \
  --bind-tcp=0.0.0.0:10000 \
  --exec-wrapper="vglrun" \
  --webcam=no \
  --start="${main_program}"