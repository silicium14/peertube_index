defmodule Mix.Tasks.SeedFromTheFederationInfo do
  use Mix.Task

  @moduledoc """
  Fetches instances from the-federation.info and adds the not yet known instances to the instance storage
  """

  @shortdoc """
  Fetches instances from the-federation.info and adds the not yet known instances to the instance storage
  """
  def run(_) do
    Application.ensure_all_started :httpoison
    Application.ensure_all_started :ecto_sql
    Application.ensure_all_started :postgrex
    PeertubeIndex.StatusStorage.Repo.start_link()

    query = "{nodes(platform: \"peertube\") {host}}"
    url = URI.encode("https://the-federation.info/graphql?query=" <> query)
    {:ok, response} = HTTPoison.get(url)

    response.body
    |> Poison.decode!()
    |> Map.get("data")
    |> Map.get("nodes")
    |> Enum.map(fn instance -> instance["host"] end)
    |> MapSet.new()
    |> Enum.to_list()
    |> PeertubeIndex.add_instances()
  end
end
