use Mix.Config

config :peertube_index,
  video_storage: PeertubeIndex.VideoStorage.Elasticsearch,
  instance_api: PeertubeIndex.InstanceAPI.Httpc,
  status_storage: PeertubeIndex.StatusStorage.Filesystem
