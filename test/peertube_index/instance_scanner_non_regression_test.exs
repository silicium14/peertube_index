defmodule InstanceScannerNonRegressionTest do
  use ExUnit.Case, async: false
  @moduledoc """
  Non regression tests for PeerTube instance scanner module.
  The state of the reference PeerTube instance we use changes frequently,
  to take this this into account we suggest the following workflow:
  - checkout to a known working version of the instance scanner module
  - update reference dataset with `mix refresh_instance_scanner_non_regression_reference`
  - checkout to the instance scanner module version to test
  - run this test
  """

  @moduletag :nonregression

  @reference_videos_file "test/peertube_index/instance_scanner_non_regression_test_data/reference_videos.json"
  @reference_instances_file "test/peertube_index/instance_scanner_non_regression_test_data/reference_instances.json"
  @result_videos_file "test/peertube_index/instance_scanner_non_regression_test_data/videos.json"
  @result_instances_file "test/peertube_index/instance_scanner_non_regression_test_data/instances.json"

  setup_all do
    {:ok, {videos, instances}} = PeertubeIndex.InstanceScanner.Http.scan("peertube.cpy.re", 5)
    videos = Enum.to_list(videos)

    # Save results for debugging
    File.write!(
      @result_videos_file,
      Poison.encode!(videos, pretty: true),
      [:binary, :write]
    )
    File.write!(
      @result_instances_file,
      Poison.encode!(MapSet.to_list(instances), pretty: true),
      [:binary, :write]
    )

    %{videos: videos, instances: instances}
  end

  test "scan gives the same videos", %{videos: videos} do
    expected = @reference_videos_file |> File.read!() |> Poison.decode!
    assert videos == expected, "Results differ from reference, compare reference: #{@reference_videos_file} with results: #{@result_videos_file}"
  end

  test "scan gives the same instances", %{instances: instances} do
    expected = @reference_instances_file |> File.read!() |> Poison.decode! |> MapSet.new
    assert MapSet.equal?(instances, expected), "Results differ from reference, compare reference: #{@reference_instances_file} with results: #{@result_instances_file}"
  end
end
