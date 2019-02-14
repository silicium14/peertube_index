# PeertubeIndex

## Decisions
- We should not put too much pressure on instances by querying them heavily so we scan one instance sequentially.
- Our validation of video documents expects fields that are not in PeerTube OpenAPI spec but that we found were provided by most instances.
We should check monitor video document validation errors per PeerTube instance version to make sure our validation works correctly for newer versions.


## How to run the project
### Development
- To run Elasticsearch in docker
```bash
docker run -d --name peertube-index-elasticsearch -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" docker.elastic.co/elasticsearch/elasticsearch:6.5.4
# For tests
docker run -d --name peertube-index-elasticsearch-test -p 5555:9200 -e "discovery.type=single-node" docker.elastic.co/elasticsearch/elasticsearch:6.5.4
```

- To start iex
This project relies on environment variables for configuration, see the `config.exs` file for the environment variables you need to set
```bash
HTTP_API_PORT=4000 ELASTICSEARCH_URL="http://localhost:9200" STATUS_STORAGE_DIRECTORY="status_storage_dev" iex -S mix
```

- To run tests
```bash
HTTP_API_PORT=4001 ELASTICSEARCH_URL="http://localhost:5555" STATUS_STORAGE_DIRECTORY="status_storage_test" mix test
```

## TODO
- Fix HTTP 500 on http://peertube-index.net/search?text=bille
    - requires: dump and restore prod databases locally
- Upgrade elasticsearch
- Simplify infrastructure code with docker compose?
- Make deploy not failing on container deletion if a container does not exists
- HTTP Digest authentication for web frontend with a reverse proxy
- Use Hackney instead of httpc (waiting for https://github.com/PSPDFKit-labs/bypass/issues/75)
- Figure why httpc truncates response in some cases or change http client
- respect `/robots.txt`?
- Sensitive content warning start page?
- Ban instance/account/video from search results use case?
    - Report feature?
- Scan loop optimization: first ensure compatible PeerTube version with `/api/v1/config`
- Search frontend, HTML safe video data?
- Kubernetes
- Seed status storage with known instance hosts list
- Stats endpoint?
- More automated Instance API non regression tests: use our own instance?
- Deployment
    - HTTPS
- Log incoming requests
- Monitoring
- Rate limiting
- Error and not found pages
- Add an end to end test
- Scan multiple instances concurrently
- HTTP API: pagination: add number of pages to response, search use case pagination
- Status frontend
- Isolate and handle failures of the steps in scan function
- Use document type from Elasticsearch library?
- Remember that in the domain we directly use the objects returned by the storage without any conversion, we are coupled to the storage format for now
- Analysis tool check matching of collaboration and contract tests
