defmodule Mix.Tasks.SeedFromInstancesJoinpeertubeOrg do
  use Mix.Task

  @moduledoc """
  Fetches instances from instances.joinpeertube.org and adds the not yet known instances to the instance storage
  """

  @shortdoc """
  Fetches instances from instances.joinpeertube.org and adds the not yet known instances to the instance storage
  """
  def run(_) do
    Application.ensure_all_started :elasticsearch

    {:ok, response} = HTTPoison.get "https://instances.joinpeertube.org/api/v1/instances?count=1000000000000000000"
    response.body
    |> Poison.decode!()
    |> Map.get("data")
    |> Enum.map(fn instance -> instance["host"] end)
    |> MapSet.new()
    |> Enum.to_list()
    |> PeertubeIndex.add_instances()
  end
end
