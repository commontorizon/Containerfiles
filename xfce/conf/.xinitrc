#!/bin/sh

export XDG_RUNTIME_DIR=/tmp/xdg
export X11_UNIX_SOCKET="/tmp/.X11-unix"
export XDG_RUNTIME_DIR=/tmp/$(id -u torizon)-runtime-dir
export XAUTHORITY=/tmp/.Xauthority
export DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-session-bus

startxfce4 &

sleep 15s
chown torizon:torizon /tmp/.Xauthority
echo "calling onboard ..."
onboard
