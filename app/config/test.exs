use Mix.Config

config :peertube_index,
  video_storage: PeertubeIndex.VideoStorage.Mock,
  instance_scanner: PeertubeIndex.InstanceScanner.Mock,
  status_storage: PeertubeIndex.StatusStorage.Mock

config :gollum,
  refresh_secs: 0, # Amount of time before the robots.txt will be refetched
  lazy_refresh: true, # Whether to setup a timer that auto-refetches, or to only refetch when requested
  user_agent: "PeertubeIndex" # User agent to use when sending the GET request for the robots.txt

config :logger,
  level: :warn
