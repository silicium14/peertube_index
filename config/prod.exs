use Mix.Config

config :peertube_index,
  video_storage: PeertubeIndex.VideoStorage.Elasticsearch,
  instance_api: PeertubeIndex.InstanceScanner.Http,
  status_storage: PeertubeIndex.StatusStorage.Filesystem
