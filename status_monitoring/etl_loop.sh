#!/usr/bin/env bash

function load {
    elixir join_statuses.exs
    psql \
        -h peertube-index-status-monitoring-db \
        -U postgres \
        -f load.sql \
        -v import_time="'$(TZ=UTC date '+%Y-%m-%d %H:%M:%S')'"
}

while [ 1 ]; do
    echo "$(date) Start loading"
    load
    echo "$(date) Finished loading"
    sleep 300
    test $? -gt 128 && break
done
