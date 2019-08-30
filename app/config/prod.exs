use Mix.Config

config :peertube_index,
  video_storage: PeertubeIndex.VideoStorage.Elasticsearch,
  instance_scanner: PeertubeIndex.InstanceScanner.Http,
  status_storage: PeertubeIndex.StatusStorage.Postgresql

config :gollum,
  refresh_secs: 10, # Amount of time before the robots.txt will be refetched
  lazy_refresh: true, # Whether to setup a timer that auto-refetches, or to only refetch when requested
  user_agent: "PeertubeIndex" # User agent to use when sending the GET request for the robots.txt
