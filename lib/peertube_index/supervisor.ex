defmodule PeertubeIndex.Supervisor do
  @moduledoc false
  

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_arg) do
    children = [
      {Task.Supervisor, name: PeertubeIndex.ScanningSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
