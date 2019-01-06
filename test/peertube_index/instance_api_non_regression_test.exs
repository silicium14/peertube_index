defmodule InstanceApiNonRegressionTest do
  use ExUnit.Case, async: true
  @moduledoc """
  Non regression tests for PeerTube instance API module.
  The state of the reference PeerTube instance we use changes frequently,
  to take this this into account we suggest the following workflow:
  - checkout to a known working version of the instance API module
  - update reference dataset with `mix refresh_instance_api_non_regression_reference`
  - checkout to the instance API module version to test
  - run this test
  """

  @moduletag :integration

  @reference_videos_file "test/peertube_index/instance_api_non_regression_test_data/reference_videos.json"
  @reference_instances_file "test/peertube_index/instance_api_non_regression_test_data/reference_instances.json"
  @result_videos_file "test/peertube_index/instance_api_non_regression_test_data/videos.json"
  @result_instances_file "test/peertube_index/instance_api_non_regression_test_data/instances.json"

  setup_all do
    {:ok, {videos, instances}} = PeertubeIndex.InstanceAPI.Httpc.scan("peertube.cpy.re", 5)

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
