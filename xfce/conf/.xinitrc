#!/bin/sh

export X11_UNIX_SOCKET="/tmp/.X11-unix"
export XDG_RUNTIME_DIR=/tmp/$(id -u torizon)-runtime-dir
export XAUTHORITY=/tmp/.Xauthority
export DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-session-bus

startxfce4 &

sleep 15s
chown torizon:torizon /tmp/.Xauthority

# wait until we have the display set
while ! DISPLAY=:0 xset -q; do
    sleep 15s
done

echo "calling onboard ..."
onboard
