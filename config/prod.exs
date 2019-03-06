use Mix.Config

config :peertube_index,
  video_storage: PeertubeIndex.VideoStorage.Elasticsearch,
  instance_scanner: PeertubeIndex.InstanceScanner.Http,
  status_storage: PeertubeIndex.StatusStorage.Filesystem
