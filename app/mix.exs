defmodule PeertubeIndex.MixProject do
  use Mix.Project

  def project do
    [
      app: :peertube_index,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env),
    ]
  end

  def elixirc_paths(:test), do: ["test/support", "lib"]
  def elixirc_paths(_),     do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {PeertubeIndex.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:confex, "~> 3.4"},
      {:ecto_sql, "~> 3.1"},
      {:postgrex, ">= 0.0.0"},
      {:elasticsearch, "~> 1.0"},
      {:gollum, github: "silicium14/gollum", ref: "ff84c9c00433ce0d5ff75697ec2f32d34750d6d8"},
      {:phoenix_html, "~> 2.13"},
      {:plug, "~> 1.8"},
      {:plug_cowboy, "~> 2.0"},
      {:poison, "~> 4.0"},
      # Dev only
      {:bypass, "~> 1.0.0", only: :test},
      {:credo, "~> 1.1", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false},
      {:mox, "~> 0.5.1", only: :test},
      {:remix, "~> 0.0.2", only: :dev}
    ]
  end
end
