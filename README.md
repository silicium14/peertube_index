# PeertubeIndex

## Decisions
We should not put too much pressure on instances by querying them heavily so we scan one instance sequentially.

## Tests

To run storage tests you need an ElasticSearch instance running.
Use config/test.exs configure the instance to use for the tests.

## Infrastructure
To run Elasticsearch in docker
docker run -d --name peertube-index-elasticsearch -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" elasticsearch:6.4.2
docker run -d --name peertube-index-elasticsearch-test -p 5555:9200 -e "discovery.type=single-node" elasticsearch:6.4.2

## TODO
- HTTP API: pagination: add number of pages to response, search use case pagination
- Search pagination
- Error and not found pages
- Add an end to end test
- Scan multiple instances concurrently
- Scan works with http and detects https or http
- Seed status storage with known instance hosts list
- Search frontend
- Search pagination
- Search filter NSFW
- Status frontend
- Isolate and handle failures of the steps in scan function
- Refine search behaviour
- Use document type from Elasticsearch library?
- Remember that in the domain we directly use the objects returned by the storage without any conversion, we are coupled to the storage format for now
