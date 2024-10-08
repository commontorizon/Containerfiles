#!/bin/sh

# default URL
URL="www.torizon.io"

if [ ! -z "$1" ]; then
    URL=$1
fi

OPTION=$2
COG_COMMAND="cog $URL"
WAIT4_COMMAND="/usr/bin/wait4 $URL '$COG_COMMAND'"

if [ ! -z "$2" ] && [ "$2" = "-w" ]; then
    # use the wait4 to wait the webserver to be up
    eval exec $WAIT4_COMMAND
else
    eval exec $COG_COMMAND
fi
