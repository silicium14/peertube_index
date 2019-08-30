#!/usr/bin/env bash

# Backup the entire elasticsearch snapshot repository to a tar file on the server and download it to a local directory

# Example usage:
# infrastructure/elasticsearch_snapshot.sh user@hostname.domain destination_directory

# Arguments:
#  First argument: ssh destination for the server running docker compose stack, example: user@hostname.domain
#  Second argument: local destination directory for the tar backup file

set -e
set -x

MACHINE_SSH_DESTINATION="$1"
LOCAL_DIRECTORY="$2"

SNAPSHOT="snapshot-$(date '+%F_%H-%M-%S')"

ssh ${MACHINE_SSH_DESTINATION} << END_OF_REMOTE_SCRIPT
    set -e
    set -x

    docker exec peertube-index_elasticsearch_1 \
        curl -v --fail -X PUT "localhost:9200/_snapshot/videos/${SNAPSHOT}?wait_for_completion=true&pretty=true"

    mkdir -p /root/elasticsearch_backups
    docker cp -a peertube-index_elasticsearch_1:/backups - > /root/elasticsearch_backups/${SNAPSHOT}.tar
END_OF_REMOTE_SCRIPT

rsync -z ${MACHINE_SSH_DESTINATION}:/root/elasticsearch_backups/${SNAPSHOT}.tar ${LOCAL_DIRECTORY}

# Remove snapshot from Elasticsearch repository after download
ssh ${MACHINE_SSH_DESTINATION} << END_OF_REMOTE_SCRIPT
    set -e
    set -x

    docker exec peertube-index_elasticsearch_1 \
        curl -v --fail -X DELETE "localhost:9200/_snapshot/videos/${SNAPSHOT}?pretty=true"
END_OF_REMOTE_SCRIPT

echo "Finished, snapshot name: ${SNAPSHOT}"