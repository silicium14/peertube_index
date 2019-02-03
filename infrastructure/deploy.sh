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

    docker build -t peertube-index-traefik:${VERSION} infrastructure/traefik
    docker image save -o infrastructure/builds/peertube-index-traefik-image-${VERSION}.tar peertube-index-traefik:${VERSION}

    rsync -avz infrastructure/builds/peertube-index-image-${VERSION}.tar ${MACHINE_SSH_DESTINATION}:
    rsync -avz infrastructure/builds/peertube-index-traefik-image-${VERSION}.tar ${MACHINE_SSH_DESTINATION}:

    export NETWORK=peertube-index
    export ELASTICSEARCH_URL='http://peertube-index-elasticsearch:9200'
    export HTTP_API_PORT=80

    ssh ${MACHINE_SSH_DESTINATION} << END_OF_REMOTE_SCRIPT
        set -e
        set -x

        docker image load -i peertube-index-traefik-image-${VERSION}.tar
        docker tag peertube-index-traefik:${VERSION} peertube-index-traefik:latest
        docker stop peertube-index-traefik
        docker rm peertube-index-traefik
        docker run \
            -d \
            --restart always \
            --network ${NETWORK} \
            -p 80:80 \
            --name peertube-index-traefik \
            peertube-index-traefik:${VERSION}

        docker image load -i peertube-index-image-${VERSION}.tar
        docker tag peertube-index:${VERSION} peertube-index:latest
        docker stop peertube-index
        docker rm peertube-index
        docker run \
            -d \
            --restart always \
            --network ${NETWORK} \
            -e ELASTICSEARCH_URL=${ELASTICSEARCH_URL} \
            -e STATUS_STORAGE_DIRECTORY='/status_storage' \
            -e HTTP_API_PORT=${HTTP_API_PORT} \
            -v status_storage:/status_storage \
            --name peertube-index \
            peertube-index:${VERSION}

        docker stop peertube-index-scan-loop
        docker rm peertube-index-scan-loop
        docker run \
            -d \
            --restart always \
            --network ${NETWORK} \
            -e ELASTICSEARCH_URL=${ELASTICSEARCH_URL} \
            -e STATUS_STORAGE_DIRECTORY='/status_storage' \
            -e HTTP_API_PORT=${HTTP_API_PORT} \
            -v status_storage:/status_storage \
            --name peertube-index-scan-loop \
            peertube-index:${VERSION} \
            bash scan_loop.sh
END_OF_REMOTE_SCRIPT

    echo "# Finished, deploy successful for version ${VERSION}"
}

deploy 2>&1 | tee -a infrastructure/deploy.log
