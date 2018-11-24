use Mix.Config

config :peertube_index,
  elasticsearch_config: %{url: "http://localhost:9200", api: Elasticsearch.API.HTTP},
  video_storage: PeertubeIndex.VideoStorage.Elasticsearch,
  instance_api: PeertubeIndex.InstanceAPI.Httpc,
  status_storage: PeertubeIndex.StatusStorage.NotImplementedYet
  