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

    docker build -t peertube-index/app:${VERSION} .
    docker image save -o "${ARTIFACTS_DIRECTORY}/app-image-${VERSION}.tar" peertube-index/app:${VERSION}

    docker build -t peertube-index/error-pages:${VERSION} infrastructure/error_pages
    docker image save -o "${ARTIFACTS_DIRECTORY}/error-pages-image-${VERSION}.tar" peertube-index/error-pages:${VERSION}

    docker build -t peertube-index/status-monitoring-updater:${VERSION} status_monitoring
    docker image save -o "${ARTIFACTS_DIRECTORY}/status-monitoring-updater-image-${VERSION}.tar" peertube-index/status-monitoring-updater:${VERSION}

    docker build -t peertube-index/node-exporter-relay:${VERSION} infrastructure/node_exporter
    docker image save -o "${ARTIFACTS_DIRECTORY}/node-exporter-relay-image-${VERSION}.tar" peertube-index/node-exporter-relay:${VERSION}

    cp infrastructure/traefik.toml "${ARTIFACTS_DIRECTORY}/traefik.toml"
    cp "${MONITORING_USERS_CREDENTIALS_FILE}" "${ARTIFACTS_DIRECTORY}/monitoring_users_credentials.htdigest"
    cp infrastructure/prometheus.yml "${ARTIFACTS_DIRECTORY}/prometheus.yml"
    cp docker-compose.yml "${ARTIFACTS_DIRECTORY}/docker-compose.yml"
    echo "COMPOSE_PROJECT_NAME=peertube-index" > "${ARTIFACTS_DIRECTORY}/.env"

    # local artifacts directory must not have a trailing slash to send the directory and not just the files inside
    rsync -rtvz "infrastructure/builds/${VERSION}" ${MACHINE_SSH_DESTINATION}:"/root/"
    export SERVER_ARTIFACTS_DIRECTORY="/root/${VERSION}/"

    ssh ${MACHINE_SSH_DESTINATION} << END_OF_REMOTE_SCRIPT
        set -e
        set -x

        export ARTIFACTS_DIRECTORY="${SERVER_ARTIFACTS_DIRECTORY}"
        export VERSION="${VERSION}"

        function load_and_replace_prod_image {
            IMAGE_NAME="\$1"

            docker image load -i \${ARTIFACTS_DIRECTORY}/\${IMAGE_NAME}-image-\${VERSION}.tar
            # Tag previous prod image as previous_prod if it exists
            if docker image inspect peertube-index/\${IMAGE_NAME}:prod > /dev/null
            then
                docker tag peertube-index/\${IMAGE_NAME}:prod peertube-index/\${IMAGE_NAME}:previous_prod
            fi
            docker tag peertube-index/\${IMAGE_NAME}:\${VERSION} peertube-index/\${IMAGE_NAME}:prod
        }

        for image in node-exporter-relay status-monitoring-updater app error-pages; do
            echo "Loading image \${image}"
            load_and_replace_prod_image \${image}
        done

        cd "\${ARTIFACTS_DIRECTORY}"

        # Remove prometheus container to avoid this error: Cannot create container for service prometheus: Duplicate mount point: /prometheus
        docker-compose rm -sf prometheus

        docker-compose up -d --no-build
END_OF_REMOTE_SCRIPT

echo "# Finished, deploy successful for version ${VERSION}"
}

deploy 2>&1 | tee -a infrastructure/deploy.log
