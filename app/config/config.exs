use Mix.Config

config :peertube_index,
  elasticsearch_config: %{
    url: {:system, "ELASTICSEARCH_URL"}, # The URL to reach ElasticSearch, for example: http://localost:9200
    api: Elasticsearch.API.HTTP
  },
  status_storage_database_url: {:system, "STATUS_STORAGE_DATABASE_URL"},
  http_api_port: {:system, :integer, "HTTP_API_PORT"}, # The TCP port used to listen to incoming HTTP requests for the API, for example: 80
  ecto_repos: [PeertubeIndex.StatusStorage.Repo]

import_config "#{Mix.env}.exs"
