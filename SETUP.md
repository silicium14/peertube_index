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
- Create a monitoring users digest authentication file (locally)
- Start host metrics exporter (on the server)
- Change Elasticsearch container configuration for a first deploy (locally)
- Run a first deploy (locally)
- Create Elasticsearch index (on the server)
- Create Elasticsearch snapshot repository (on the server)

### Manage monitoring users digest authentication (locally)
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

### Start host metrics exporter (on the server)
See `node_exporter_relay/setup_node_exporter.md`

### Change Elasticsearch container configuration for a first deploy (locally)
In the `docker-compose.yml` file, add the following environment variable to the elasticsearch container:
```
cluster.initial_master_nodes: "elasticsearch"
```
This is required by Elasticsearch to start safely start new cluster.
You can remove this environment variable after the first deploy.

### Run a first deploy (locally)
```bash
MACHINE_SSH_DESTINATION="user@hostname.domain" \
MONITORING_USERS_CREDENTIALS_FILE="monitoring_users_credentials_file.htdigest" \
./scripts/deploy.sh
```
Some containers will be giving failure messages because Elasticsearch index and status storage are not created yet.
Use the same command for next deploys.

### Create Elasticsearch index (on the server)
Start an iex session inside the webapp container, without starting the app
```bash
docker exec -it peertube-index_webapp_1 iex -S mix run --no-start
```
Then, in the iex session
```elixir
Application.ensure_all_started :elasticsearch
PeertubeIndex.VideoStorage.Elasticsearch.empty!()
```

### Create Elasticsearch snapshot repository (on the server)
This is necessary for making backups of Elasticsearch.
Open an shell in the Elasticsearch container
```bash
docker exec -it peertube-index_elasticsearch_1 /bin/bash
```
Then, in the Elasticsearch container
```bash
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