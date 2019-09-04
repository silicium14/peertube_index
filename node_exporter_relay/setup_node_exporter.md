# Install procedure
```bash
cd /root/
wget https://github.com/prometheus/node_exporter/releases/download/v0.18.1/node_exporter-0.18.1.linux-amd64.tar.gz
tar xvzf node_exporter-0.18.1.linux-amd64.tar.gz
```

# Start node_exporter
```bash
cd /root/node_exporter-0.18.1.linux-amd64
./node_exporter --web.listen-address="127.0.0.1:9100" --log.level debug
```

# Listen on unix socket and forward requests to node_exporter
Why using a socket?
Because the firewall does not allow the containers to talk with the host machine.
We prefer to share a socket file than configuring the firewall.

```bash
mkdir /tmp/node_exporter/
socat -d -d -d UNIX-LISTEN:/tmp/node_exporter/node_exporter.sock,fork TCP4:127.0.0.1:9100
```

The `/tmp/node_exporter` directory can now be mounted to the node-exporter-relay container that runs socat to forward incoming requests to the socket.
