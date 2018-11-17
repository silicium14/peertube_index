use Mix.Config

config :peertube_index,
  # Only used for integration tests
  elasticsearch_config: %{url: "http://localhost:5555", api: Elasticsearch.API.HTTP},
  # Only used for integration tests
  instance_api: PeertubeIndex.InstanceAPI.Mock,
  storage: PeertubeIndex.Storage.Mock
