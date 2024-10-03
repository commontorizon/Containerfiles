#!/bin/bash

URL="$1"
TIMEOUT=300
CMD="$2"


echo "start"
XSTATUS=502
while [ $XSTATUS -eq 502 ] || [ $XSTATUS -eq 404 ] || [ $XSTATUS -eq 000 ]; do
    sleep 1
    XSTATUS=`curl -s --connect-timeout $TIMEOUT -o /dev/null -w "%{http_code}" $URL`
    echo "current HTTP STATUS is $XSTATUS"
done

echo "service is up and running "
echo "now executing $CMD "

eval exec $CMD
