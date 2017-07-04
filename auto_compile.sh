#!/usr/bin/env bash

### Set initial time of file
LTIME=''

while true
do
    ATIME=''
    ATIME+=`stat -c %Z ./*`

    if [[ "$ATIME" != "$LTIME" ]]
    then
        echo "compiling!"
        ./compile.rb
        echo 'done!'
        LTIME=`stat -c %Z ./*`
    fi
    sleep 0.5
done
