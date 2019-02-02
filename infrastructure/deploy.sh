#!/usr/bin/env bash

# Deploy the API and the scan loop
# Expected environment variables:
#   MACHINE_SSH_DESTINATION: user@hostname.domain

set -e
set -x

function die {
    echo "Stopping because: $1"
    exit
}

function deploy {
    export VERSION=$(git rev-parse --short --verify HEAD)
    echo "# Starting deploy for version ${VERSION}"

    [[ -n "$(git status --porcelain)" ]] && die "working directory not clean"

    docker build -t peertube-index:${VERSION} .
    docker image save -o infrastructure/builds/peertube-index-image-${VERSION}.tar peertube-index:${VERSION}
    rsync -avz infrastructure/builds/peertube-index-image-${VERSION}.tar ${MACHINE_SSH_DESTINATION}:

    ssh ${MACHINE_SSH_DESTINATION} << END_OF_REMOTE_SCRIPT
        set -e
        set -x

        docker image load -i peertube-index-image-${VERSION}.tar
        docker tag peertube-index:${VERSION} peertube-index:latest
        docker stop peertube-index \
        && docker rm peertube-index \
        && docker run \
            -d \
            --restart always \
            --network peertube-index \
            -p 80:80 \
            -e ELASTICSEARCH_URL='http://peertube-index-elasticsearch:9200' \
            -e STATUS_STORAGE_DIRECTORY='/status_storage' \
            -e HTTP_API_PORT=80 \
            -v status_storage:/status_storage \
            --name peertube-index \
            peertube-index:${VERSION}

        docker stop peertube-index-scan-loop \
        && docker rm peertube-index-scan-loop \
        && docker run \
            -d \
            --restart always \
            --network peertube-index \
            -e ELASTICSEARCH_URL='http://peertube-index-elasticsearch:9200' \
            -e STATUS_STORAGE_DIRECTORY='/status_storage' \
            -e HTTP_API_PORT=80 \
            -v status_storage:/status_storage \
            --name peertube-index-scan-loop \
            peertube-index:${VERSION} \
            bash scan_loop.sh
END_OF_REMOTE_SCRIPT

    echo "# Finished, deploy successful for version ${VERSION}"
}

deploy 2>&1 | tee -a infrastructure/deploy.log
