use Mix.Config

config :peertube_index,
  video_storage: PeertubeIndex.VideoStorage.Mock,
  instance_api: PeertubeIndex.InstanceScanner.Mock,
  status_storage: PeertubeIndex.StatusStorage.Mock
