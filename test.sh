#!/bin/bash

URL="http://example.com"  # Replace with your HTTP service URL

while true; do
    # Check HTTP accessibility
    if curl -s --connect-timeout 5 "$URL" > /dev/null; then
        echo "HTTP accessible: $URL"
    else
        echo "HTTP not accessible: $URL"
    fi

    # Check HTTPS accessibility
    if curl -s --connect-timeout 5 "https://example.com" > /dev/null; then
        echo "HTTPS accessible: https://example.com"
    else
        echo "HTTPS not accessible: https://example.com"
    fi

    echo "---------------------------------------_"
done
