use Mix.Config

config :peertube_index,
  # Only used for integration tests
  elasticsearch_config: %{url: "http://localhost:5555", api: Elasticsearch.API.HTTP},
  video_storage: PeertubeIndex.VideoStorage.Mock,
  instance_api: PeertubeIndex.InstanceAPI.Mock,
  status_storage: PeertubeIndex.StatusStorage.Mock,
  # For integration tests
  status_storage_directory: "status_storage_test"
