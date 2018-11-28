# PeertubeIndex

**TODO: Add description**

## Decisions
We should not put too much pressure on instances by querying them heavily.

## Tests

To run storage tests you need an ElasticSearch instance running.
Use config/test.exs configure the instance to use for the tests.

## Infrastructure
docker run -d --name peertube-index-elasticsearch -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" elasticsearch:6.4.2
docker run -d --name peertube-index-elasticsearch-test -p 5555:9200 -e "discovery.type=single-node" elasticsearch:6.4.2
