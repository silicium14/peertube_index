# PeertubeIndex

## Decisions
- We should not put too much pressure on instances by querying them heavily so we scan one instance sequentially.
- Our validation of video documents expects fields that are not in PeerTube OpenAPI spec but that we found were provided by most instances.
We should check monitor video document validation errors per PeerTube instance version to make sure our validation works correctly for newer versions.


## How to run the project
### Development
- To run Elasticsearch in docker
```bash
docker run -d --name peertube-index-elasticsearch-dev -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" docker.elastic.co/elasticsearch/elasticsearch:6.6.0
# For tests
docker run -d --name peertube-index-elasticsearch-test -p 5555:9200 -e "discovery.type=single-node" docker.elastic.co/elasticsearch/elasticsearch:6.6.0
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
- Background image credits
- Display the number of results, and a message if there is no result
- Home page link on every page
- About page?
- Warning page text
- Search bar icon also a button?
- Video title truncated if too long
- Functions in StatusStorage have no exclamation mark but functions in VideoStorage have one
- Some functions in StatusStorage may not return :ok as required by their spec
- Use case tests have a lot of mocking that may not be about the tested behaviour, see if we can fix it
- Thumbnails placeholder during loading OR pagination
- Handle instance timezone it such a thing exists?
- Explain ordering of results
- Bad request instead of 500 when missing search text on JSON search API
- Replace `EEx.eval_file` with `EEx.function_from_file` at compile time?
- Monitor invalid document errors by instance version to ensure that our validation still works correctly for new versions
- Simplify infrastructure code with docker compose?
- Make deploy not failing on container deletion if a container does not exists
- Use Hackney instead of httpc (waiting for https://github.com/PSPDFKit-labs/bypass/issues/75)
- Figure why httpc truncates response in some cases or change http client
- respect `/robots.txt`?
- Ban instance/account/video from search results use case?
    - Report feature?
- Scan loop optimization: check node compatibility with Nodeinfo
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
