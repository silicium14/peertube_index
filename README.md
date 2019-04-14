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
### Features
- Logo and home page link on search page
- SEO metadata
- Bigger title
- Display the number of results, and a message if there is no result / Explain ordering of results
- Monitoring: Node Exporter on the host + documentation in infrastructure/SETUP.md, Dashboard - 
- Error reporting
- Home page link on every page
- Search bar icon also a button?
- Video title truncated if too long
- Thumbnails placeholder during loading OR pagination
- Respect `/robots.txt`?
- Handle instance timezone if such a thing exists?
- Monitor invalid document errors by instance version to ensure that our validation still works correctly for new versions
- Scan metrics
- Seed status storage with known instance hosts list
- Scan loop optimization: check node compatibility with Nodeinfo
- Rate limiting
- Better looking error and not found pages
- Status frontend
- Provide search for unsafe content
- Zero downtime deploy
- Staging configuration and provisioning for a prod backup
- Healthchecks in monitoring

### Enhancements
- Upgrade Elasticsearch
- Send config file instead of docker image for traefik?
- Simplify infrastructure code with docker compose?
- Keep track of all updatable components (containers and dependencies)
- Build script and upload script
- HTTPS on Grafana
- Elasticsearch metrics
- Setup may not need to create docker volumes explicitly, see https://docs.docker.com/storage/volumes/#start-a-container-with-a-volume
- Separate infrastructure before making code public?
- Install script should `cd` into the appropriate directory to work
- Measure test coverage
- Better function names for StatusStorage functions to change the status?
- Functions in StatusStorage have no exclamation mark but functions in VideoStorage have one
- Replace `EEx.eval_file` with `EEx.function_from_file` at compile time?
- Update setup procecure
- Make deploy not failing on container deletion if a container does not exists
- Use Hackney instead of httpc (waiting for https://github.com/PSPDFKit-labs/bypass/issues/75)
- Figure why httpc truncates response in some cases or change http client
- Instance scanner non regression tests with a cassette that replays a real payload in tests
- Add an end to end test
- Scan multiple instances concurrently
- Use document type from Elasticsearch library?
- Remember that in the domain we directly use the objects returned by the storage without any conversion, we are coupled to the storage format for now
- Analysis tool check matching of collaboration and contract tests
