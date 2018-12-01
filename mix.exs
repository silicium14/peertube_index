defmodule PeertubeIndex.MixProject do
  use Mix.Project

  def project do
    [
      app: :peertube_index,
      version: "0.1.0",
      elixir: "~> 1.7",
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
      {:elasticsearch, "~> 0.6.0"},
      {:poison, "~> 4.0"},
      {:plug, "~> 1.7"},
      {:plug_cowboy, "~> 2.0"},
      {:credo, "~> 1.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false},
      {:bypass, "~> 1.0.0", only: :test},
      {:mox, "~> 0.4.0", only: :test},
      {:remix, "~> 0.0.2", only: :dev}
    ]
  end
end
