# PeertubeIndex

## Decisions
We should not put too much pressure on instances by querying them heavily so we scan one instance sequentially.

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
- Use a single file for behaviour and their implementation if there is only one implementation (auto generated mocks for testing do not count)
- Use Hackney instead of httpc
- Handle the case of scan failure but instance has videos in video storage
- Rename InstanceAPI to InstanceScanner
- Figure why httpc truncates response in some cases or change http client
- Kubernetes
- Seed status storage with known instance hosts list
- Stats endpoint?
- More automated Instance API non regression tests: use our own instance?
- Deployment
    - HTTPS
- Log incoming requests
- Monitoring
- HTTP API: pagination: add number of pages to response, search use case pagination
- Error and not found pages
- Add an end to end test
- Scan multiple instances concurrently
- Search frontend
- Status frontend
- Isolate and handle failures of the steps in scan function
- Use document type from Elasticsearch library?
- Remember that in the domain we directly use the objects returned by the storage without any conversion, we are coupled to the storage format for now
- Analysis tool check matching of collaboration and contract tests
