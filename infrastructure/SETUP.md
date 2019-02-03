# Production Digitalocean droplet with docker installed
## System setup
Add this to `/etc/sysctl.conf`
```
# Added by hand, trying to prevent reaching conntrack tracking limit that cause denial of service
net.netfilter.nf_conntrack_tcp_timeout_established = 54000
net.netfilter.nf_conntrack_generic_timeout = 120

# Added by hand, needed for elasticsearch
vm.max_map_count = 262144
```
Add this to root crontab to apply sysctl settings on boot
`@reboot sleep 15; /sbin/sysctl -p`

## Infrastructure setup
### Creation of docker network and volumes, and startup of Elasticsearch
On the server
```bash
docker network create peertube-index
docker volume create status_storage
docker volume create elasticsearch_data
docker run \
    -d \
    --restart always \
    --network peertube-index \
    --name peertube-index-elasticsearch \
    -e "discovery.type=single-node" \
    -e "cluster.name=peertube-index-cluster" \
    -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
    -v elasticsearch_data:/usr/share/elasticsearch/data \
    --ulimit memlock=-1:-1 \
    docker.elastic.co/elasticsearch/elasticsearch:6.5.4
```

### Build and upload of docker images to the server
Locally
```bash
export VERSION=$(git rev-parse --short --verify HEAD)

docker build -t peertube-index:${VERSION} .
docker image save -o infrastructure/builds/peertube-index-image-${VERSION}.tar peertube-index:${VERSION}

docker build -t peertube-index-traefik:${VERSION} infrastructure/traefik
docker image save -o infrastructure/builds/peertube-index-traefik-image-${VERSION}.tar peertube-index-traefik:${VERSION}

rsync -avz infrastructure/builds/peertube-index-traefik-image-${VERSION}.tar user@machine-hostname.domain:
rsync -avz infrastructure/builds/peertube-index-image-${VERSION}.tar user@machine-hostname.domain:
```

### Creation of the Elasticsearch index and the status storage directory
On the server, start an iex session inside a container with production configuration
```bash
# You need to export VERSION first, this is the version from the build step
export VERSION=xxxxxxxx

docker run \
    --rm -it \
    --network peertube-index \
    -e ELASTICSEARCH_URL='http://peertube-index-elasticsearch:9200' \
    -e STATUS_STORAGE_DIRECTORY='/status_storage' \
    -e HTTP_API_PORT=80 \
    -v status_storage:/status_storage \
    --name peertube-index-shell \
    peertube-index:${VERSION} iex -S mix
```

In the iex session
```elixir
PeertubeIndex.VideoStorage.Elasticsearch.empty()
# Not be needed if a docker volume was mounted, the directory already exists
PeertubeIndex.StatusStorage.Filesystem.empty()
```

## Starting application containers
On server
```bash
# You need to export VERSION first, this is the version from the build step
export VERSION=xxxxxxxx

# API
docker run \
    -d \
    --restart always \
    --network peertube-index \
    -e ELASTICSEARCH_URL='http://peertube-index-elasticsearch:9200' \
    -e STATUS_STORAGE_DIRECTORY='/status_storage' \
    -e HTTP_API_PORT=80 \
    -v status_storage:/status_storage \
    --name peertube-index \
    peertube-index:${VERSION}

# Scan loop
docker run \
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
    
# Reverse proxy
docker run \
    -d \
    --restart always \
    --network peertube-index \
    -p 80:80 \
    --name peertube-index-traefik \
    peertube-index-traefik:${VERSION}
```

# Deployments after first setup
```bash
MACHINE_SSH_DESTINATION=user@hostname.domain ./infrastructre/deploy.sh
```