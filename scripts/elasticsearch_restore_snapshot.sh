#!/usr/bin/env bash

# Restore an elasticsearch snapshot repository tar backup to an elasticsearch instance running in a container

# Example usage:
# infrastructure/elasticsearch_restore_snapshot.sh path/to/backup.tar container snapshot-name

# Arguments:
#  First argument: elasticsearch snapshot repository tar backup
#  Second argument: elasticsearch container name
#  Third argument: snapshot name

set -e
set -x

BACKUP_FILE="$(realpath "$1")"
DESTINATION_CONTAINER="$2"
SNAPSHOT="$3"

docker cp - "${DESTINATION_CONTAINER}":/ < "${BACKUP_FILE}"

docker exec \
    ${DESTINATION_CONTAINER} \
    curl -v --fail -X POST "localhost:9200/_snapshot/videos/${SNAPSHOT}/_restore?wait_for_completion=true&pretty=true"

echo "Finished restoring snapshot ${SNAPSHOT}"
