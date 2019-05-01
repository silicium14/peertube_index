#!/usr/bin/env bash

# Deploy the API and the scan loop
# Expected environment variables:
#   MACHINE_SSH_DESTINATION: user@hostname.domain
#   MONITORING_USERS_CREDENTIALS_FILE: path of monitoring user credentials in htdigest format

set -e
set -x

function die {
    echo "Stopping because: $1"
    exit
}

function deploy {
    export VERSION=$(git rev-parse --short --verify HEAD)
    export ARTIFACTS_DIRECTORY="infrastructure/builds/${VERSION}/"
    echo "# Starting deploy for version ${VERSION}"

    [[ -n "$(git status --porcelain)" ]] && die "working directory not clean"

    mkdir "${ARTIFACTS_DIRECTORY}"

    docker build -t peertube-index:${VERSION} .
    docker image save -o "${ARTIFACTS_DIRECTORY}/peertube-index-image-${VERSION}.tar" peertube-index:${VERSION}

    docker build -t peertube-index-error-pages:${VERSION} infrastructure/error_pages
    docker image save -o "${ARTIFACTS_DIRECTORY}/peertube-index-error-pages-image-${VERSION}.tar" peertube-index-error-pages:${VERSION}

    docker build -t peertube-index-status-monitoring-updater:${VERSION} status_monitoring
    docker image save -o "${ARTIFACTS_DIRECTORY}/peertube-index-status-monitoring-updater-image-${VERSION}.tar" peertube-index-status-monitoring-updater:${VERSION}

    cp infrastructure/traefik.toml "${ARTIFACTS_DIRECTORY}/traefik.toml"
    cp "${MONITORING_USERS_CREDENTIALS_FILE}" "${ARTIFACTS_DIRECTORY}/monitoring_users_credentials.htdigest"
    cp infrastructure/prometheus.yml "${ARTIFACTS_DIRECTORY}/prometheus.yml"

    # local artifacts directory must not have a trailing slash to send the directory and not just the files inside
    rsync -rtvz "infrastructure/builds/${VERSION}" ${MACHINE_SSH_DESTINATION}:"/root/"
    export SERVER_ARTIFACTS_DIRECTORY="/root/${VERSION}/"


    export NETWORK=peertube-index
    export ELASTICSEARCH_URL='http://peertube-index-elasticsearch:9200'
    export HTTP_API_PORT=80

    ssh ${MACHINE_SSH_DESTINATION} << END_OF_REMOTE_SCRIPT
        set -e
        set -x

        docker image load -i ${SERVER_ARTIFACTS_DIRECTORY}/peertube-index-status-monitoring-updater-image-${VERSION}.tar
        docker tag peertube-index-status-monitoring-updater:${VERSION} peertube-index-status-monitoring-updater:latest
        docker stop peertube-index-status-monitoring-updater
        docker rm peertube-index-status-monitoring-updater
        docker run \
            -d \
            --restart always \
            --network ${NETWORK} \
            -v status_storage:/status_storage:ro \
            --name peertube-index-status-monitoring-updater \
            peertube-index-status-monitoring-updater:${VERSION}

        docker stop peertube-index-prometheus
        docker rm peertube-index-prometheus
        docker run \
            -d \
            --restart always \
            --network ${NETWORK} \
            -v prometheus_data:/prometheus \
            -v "${SERVER_ARTIFACTS_DIRECTORY}/prometheus.yml":/etc/prometheus/prometheus.yml \
            --name peertube-index-prometheus \
            prom/prometheus:v2.8.0

        docker stop peertube-index-grafana
        docker rm peertube-index-grafana
        docker run \
            -d \
            --restart always \
            --network ${NETWORK} \
            -v grafana_data:/var/lib/grafana \
            --name peertube-index-grafana \
            grafana/grafana:6.0.1

        docker image load -i ${SERVER_ARTIFACTS_DIRECTORY}/peertube-index-error-pages-image-${VERSION}.tar
        docker tag peertube-index-error-pages:${VERSION} peertube-index-error-pages:latest
        docker stop peertube-index-error-pages
        docker rm peertube-index-error-pages
        docker run \
            -d \
            --restart always \
            --network ${NETWORK} \
            --name peertube-index-error-pages \
            peertube-index-error-pages:${VERSION}

        docker stop peertube-index-traefik
        docker rm peertube-index-traefik
        docker run \
            -d \
            --restart always \
            --network ${NETWORK} \
            -p 80:80 \
            -p 443:443 \
            -p 8080:8080 \
            -v ${SERVER_ARTIFACTS_DIRECTORY}/traefik.toml:/etc/traefik/traefik.toml \
            -v ${SERVER_ARTIFACTS_DIRECTORY}/monitoring_users_credentials.htdigest:/srv/monitoring_users_credentials.htdigest \
            -v traefik_acme_certs:/acme_certs \
            --name peertube-index-traefik \
            traefik:1.7-alpine

        docker image load -i ${SERVER_ARTIFACTS_DIRECTORY}/peertube-index-image-${VERSION}.tar
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
            sh scan_loop.sh

        docker stop peertube-index-seed-loop
        docker rm peertube-index-seed-loop
        docker run \
            -d \
            --restart always \
            --network ${NETWORK} \
            -e ELASTICSEARCH_URL=${ELASTICSEARCH_URL} \
            -e STATUS_STORAGE_DIRECTORY='/status_storage' \
            -e HTTP_API_PORT=${HTTP_API_PORT} \
            -v status_storage:/status_storage \
            --name peertube-index-seed-loop \
            peertube-index:${VERSION} \
            sh seed_loop.sh
END_OF_REMOTE_SCRIPT

    echo "# Finished, deploy successful for version ${VERSION}"
}

deploy 2>&1 | tee -a infrastructure/deploy.log
