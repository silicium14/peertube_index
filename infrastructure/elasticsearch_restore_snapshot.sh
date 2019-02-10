#!/usr/bin/env bash

# Restore elasticsearch snapshot to an elasticsearch instance running in a container

# Example usage:
# infrastructure/elasticsearch_restore_snapshot.sh snapshots/repository/directory container snapshot-name

# Arguments:
#  First argument: elasticserach repository directory
#  Second argument: elasticsearch container name
#  Third argument: snapshot name

set -e
set -x

BACKUP_DIRECTORY="$(realpath "$1")"
DESTINATION_CONTAINER="$2"
SNAPSHOT="$3"

docker run \
    --rm \
    -v elasticsearch_backups:/backup_volume \
    -v ${BACKUP_DIRECTORY}:/backup_directory \
    --name peertube-index-restore-elasticsearch \
    debian \
    cp -r /backup_directory/. /backup_volume/

docker exec \
    ${DESTINATION_CONTAINER} \
    curl --fail -X POST "localhost:9200/_snapshot/videos/${SNAPSHOT}/_restore?wait_for_completion=true&pretty=true"

echo "Finished restoring snapshot ${SNAPSHOT}"
