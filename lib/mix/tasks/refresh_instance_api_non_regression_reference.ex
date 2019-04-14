defmodule Mix.Tasks.RefreshInstanceScannerNonRegressionReference do
  use Mix.Task

  @moduledoc """
  Scans reference Peertube instance with the current version of the code
  and save result as the reference for instance scanner non regression tests
  """

  @shortdoc """
  Update reference data for instance scanner non regression tests
  """
  def run(_) do
    {:ok, {videos, instances}} = PeertubeIndex.InstanceScanner.Http.scan("peertube.cpy.re", 100)

    File.write!(
      "test/peertube_index/instance_api_non_regression_test_data/reference_videos.json",
      Poison.encode!(videos, pretty: true),
      [:binary, :write]
    )
    File.write!(
      "test/peertube_index/instance_api_non_regression_test_data/reference_instances.json",
      Poison.encode!(MapSet.to_list(instances), pretty: true),
      [:binary, :write]
    )
  end
end
