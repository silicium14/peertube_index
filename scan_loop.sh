#!/usr/bin/env bash

while [ 1 ]; do
    echo "$(date) Start scanning"
    { time mix run -e 'PeertubeIndex.rescan'; }
    echo "$(date) Finished scanning"
    sleep 3600
    test $? -gt 128 && break
done