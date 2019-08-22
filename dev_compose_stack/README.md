# Start a local development docker compose stack
- Execute these commands:
```shell script
source dev_compose_stack/env
docker-compose up -d
```

- Follow these steps from [SETUP.md](../SETUP.md):
    - Create Elasticsearch index (on the server);
    - Create Elasticsearch snapshot repository (on the server).

- Configure Grafana data sources and import dashboards

---
The HTTP digest authentication credentials to access monitoring are:
- user: `admin`
- password: `admin`

The Grafana credentials are:
- user: `admin`
- password: `admin`
---
