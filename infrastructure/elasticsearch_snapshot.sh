#!/usr/bin/env bash

# Backup elasticsearch data on a server and download the backup to a local directory

# Example usage:
# infrastructure/elasticsearch_snapshot.sh user@hostname.domain destination_directory

# Arguments:
#  First argument: machine ssh destination, example: user@hostname.domain
#  Second argument: local backup destination directory

set -e
set -x

MACHINE_SSH_DESTINATION="$1"
LOCAL_DIRECTORY="$2"

SNAPSHOT="snapshot-$(date '+%F_%H-%M-%S')"

ssh ${MACHINE_SSH_DESTINATION} << END_OF_REMOTE_SCRIPT
    set -e
    set -x

    docker exec \
        peertube-index-elasticsearch \
        curl -X PUT "localhost:9200/_snapshot/videos/${SNAPSHOT}?wait_for_completion=true"

    docker run \
        --rm \
        --network peertube-index \
        -v elasticsearch_backups:/backup_volume \
        -v /root/elasticsearch_backups:/backup_directory \
        --name peertube-index-backup-elasticsearch \
        debian \
        cp -r /backup_volume/. /backup_directory
END_OF_REMOTE_SCRIPT

rsync -az ${MACHINE_SSH_DESTINATION}:/root/elasticsearch_backups/ ${LOCAL_DIRECTORY}

echo "Finished, snapshot name: ${SNAPSHOT}"
