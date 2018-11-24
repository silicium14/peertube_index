use Mix.Config

config :peertube_index,
  elasticsearch_config: %{url: "http://localhost:9200", api: Elasticsearch.API.HTTP},
  storage: PeertubeIndex.Storage.Elasticsearch,
  instance_api: PeertubeIndex.InstanceAPI.Httpc,
  status_storage: PeertubeIndex.Storage.NotImplementedYet
  