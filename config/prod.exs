use Mix.Config

config :peertube_index,
  video_storage: PeertubeIndex.VideoStorage.Elasticsearch,
  instance_api: PeertubeIndex.InstanceAPI.Http,
  status_storage: PeertubeIndex.StatusStorage.Filesystem
