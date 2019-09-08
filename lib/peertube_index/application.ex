defmodule PeertubeIndex.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: PeertubeIndex.WebServer,
        options: [port: Confex.fetch_env!(:peertube_index, :http_api_port)]
      )
    ]

    opts = [strategy: :one_for_one, name: PeertubeIndex.WebServerSupervisor]
    Supervisor.start_link(children, opts)
  end
end
