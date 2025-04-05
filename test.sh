#!/bin/bash


while true; do
    if curl -s --connect-timeout 0.5 "http://127.0.0.1:6943" > /dev/null; then
        echo "6943 accessible: http://127.0.0.1:6943"
    else
        echo "6943 not accessible: http://127.0.0.1:6943"
    fi

    if curl -s --connect-timeout 0.5 "http://127.0.0.1:6942" > /dev/null; then
        echo "6942 accessible: http://127.0.0.1:6942"
    else
        echo "6942 not accessible: http://127.0.0.1:6942"
    fi

    echo "---------------------------------------"
    sleep 0.5
done
