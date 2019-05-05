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
### Creation of docker network and startup of Elasticsearch
On the server
```bash
docker network create peertube-index
docker run \
    -d \
    --restart always \
    --network peertube-index \
    --name peertube-index-elasticsearch \
    -e "discovery.type=single-node" \
    -e "cluster.name=peertube-index-cluster" \
    -e "path.repo=/backups" \
    -e "ES_JAVA_OPTS=-Xms256m -Xmx256m" \
    -v elasticsearch_data:/usr/share/elasticsearch/data \
    -v elasticsearch_backups:/backups \
    --ulimit memlock=-1:-1 \
    docker.elastic.co/elasticsearch/elasticsearch:6.6.0
```

Configure Elasticsearch backup repository, on the server
```bash
docker exec -it peertube-index-elasticsearch bash
chown -R elasticsearch:elasticsearch /backups
# Once Elasticsearch is ready
curl -X PUT "0.0.0.0:9200/_snapshot/videos" -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "videos",
    "compress": true
  }
}
'
``` 

### Creation of status monitoring database container
On the server 
```bash
docker run \
    -d \
    --restart always \
    --network peertube-index \
    -v status_monitoring_data:/var/lib/postgresql/data \
    --name peertube-index-status-monitoring-db \
    postgres:10
```

### Build and upload of docker images to the server - TODO: create build and upload script and use it here and in deploy script

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

## Starting application containers, FIXME: this is not up to date, there are more containers to start 
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
    sh scan_loop.sh
    
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
MACHINE_SSH_DESTINATION="user@hostname.domain" \
MONITORING_USERS_CREDENTIALS_FILE="monitoring_users_credentials_file.htdigest" \
./infrastructre/deploy.sh
```

## Manage monitoring users digest authentication
- Create empty htdigest file
```bash
touch monitoring_users_credentials.htdigest
``` 
- Add a user, the second parameter to `htdigest` must be `traefik`
```bash
htdigest monitoring_users_credentials.htdigest traefik username
``` 
- Remove a user
Edit the htdigest file and remove the line corresponding to the user

# Host metrics exporter
See `infrastructure/node_exporter/setup_node_exporter.md`
