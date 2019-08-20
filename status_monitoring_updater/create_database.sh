#!/usr/bin/env sh
psql \
    -h status-monitoring-db \
    -U postgres \
    -v source_host="'$SOURCE_HOST'" \
    -v source_user="'$SOURCE_USER'" \
    -v source_database="'$SOURCE_DATABASE'" \
    -f create_database.sql
