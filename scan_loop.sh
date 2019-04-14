#!/usr/bin/env sh

while [ 1 ]; do
    echo "$(date) Start scanning"
    { time mix rescan; }
    echo "$(date) Finished scanning"
    sleep 300
done
