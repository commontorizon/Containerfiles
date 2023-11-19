#!/bin/sh

# default URL
URL="www.toradex.com"

OPTION=$2
WAIT_FOR_IT_COMMAND="/usr/bin/wait-for-it $URL -t 0 --strict --"
COG_COMMAND="eval exec cog $URL"

if [ ! -z "$2" ] && [ "$2" = "-w" ]; then
    # use the wait-for-it script to wait for the webserver to be up
    $WAIT_FOR_IT_COMMAND $COG_COMMAND
else
    $COG_COMMAND
fi
