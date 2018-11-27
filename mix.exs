defmodule PeertubeIndex.MixProject do
  use Mix.Project

  def project do
    [
      app: :peertube_index,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
#      mod: {PeertubeIndex, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elasticsearch, "~> 0.6.0"},
      {:poison, "~> 4.0"},
      {:credo, "~> 1.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false},
      {:bypass, "~> 0.9.0", only: :test},
      {:plug_cowboy, "~> 1.0", only: :test},
      {:mox, "~> 0.4.0", only: :test},
      {:remix, "~> 0.0.2", only: :dev}
    ]
  end
end
