defmodule PeertubeIndex.Application do
  @moduledoc false

  use Application

  @port Application.fetch_env!(:peertube_index, :web_frontend_port)

  def start(_type, _args) do
    children = [
      Plug.Cowboy.child_spec(scheme: :http, plug: PeertubeIndex.HttpApi, options: [port: @port])
    ]

    opts = [strategy: :one_for_one, name: PeertubeIndex.HttpApiSupervisor]
    Supervisor.start_link(children, opts)
  end
end
