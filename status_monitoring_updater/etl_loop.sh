#!/usr/bin/env sh

function load {
    psql \
        -h status-monitoring-db \
        -U postgres \
        -d peertube_index \
        -v import_time="'$(TZ=UTC date '+%Y-%m-%d %H:%M:%S')'" \
        -f etl.sql
}

while [ 1 ]; do
    echo "$(date) Start loading"
    load
    echo "$(date) Finished loading"
    sleep 300
done
