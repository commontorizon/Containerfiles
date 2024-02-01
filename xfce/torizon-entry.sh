#!/bin/bash

# exits immediately if any error has non-zero exit
set -e
# error the whole pipeline if a subcommand fails
set -o pipefail

export XDG_RUNTIME_DIR=/tmp/xdg
export X11_UNIX_SOCKET="/tmp/.X11-unix"
export XDG_RUNTIME_DIR=/tmp/$(id -u torizon)-runtime-dir
export XAUTHORITY=/tmp/.Xauthority
export DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-session-bus
export DISPLAY=:0

function start_dbus()
{
        # run as torizon user
        dbus-daemon --session --address=unix:path=/tmp/dbus-session-bus &
}

function init()
{
        # echo error message, when executable file doesn't exist.
        if CMD=$(command -v "$1" 2>/dev/null); then
                shift

                exec "$CMD" "$@"
        else
                echo "Command not found: $1"

                # houston we have a problem
                exit 1
        fi
}

start_dbus
echo "The command is :: $@"
init $@
