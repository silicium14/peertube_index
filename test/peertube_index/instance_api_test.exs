defmodule PeertubeIndex.InstanceAPITest do
  use ExUnit.Case

  @moduletag :integration

  setup do
    bypass = Bypass.open
    {:ok, bypass: bypass}
  end

  # TODO: ignore changes in demo instance for tests OR use our own test instance

  test "we can fetch videos" do
    # Fetch videos from demo PeerTube instance that we use as reference
    # Videos are sorted by creation date
    # Videos are local to the instance
    # videos are fetched across multiple pages
    expected = File.read!("test/peertube_index/instance_api_test_data/videos.json") |> Poison.decode!
    {:ok, {videos, _instances}} = PeertubeIndex.InstanceAPI.Httpc.scan("peertube.cpy.re", 5)
    assert videos == expected
  end

  # Execute this code to refresh the reference data for fetching videos test
  def refresh_fetch_video_test_data() do
    {:ok, {videos, _instances}} = PeertubeIndex.InstanceAPI.Httpc.scan("peertube.cpy.re", 5)
    File.write!(
      "test/peertube_index/instance_api_test_data/videos.json",
      Poison.encode!(videos, pretty: true),
      [:binary, :write]
    )
  end

  test "we can discover instances" do
    expected = File.read!("test/peertube_index/instance_api_test_data/instances.json") |> Poison.decode! |> MapSet.new

    # Discover instances from demo PeerTube instance that we use as reference
    # Found instance set must not contain the scanned instance
    {:ok, {_videos, instances}} = PeertubeIndex.InstanceAPI.Httpc.scan("peertube.cpy.re")

    only_in_expected = MapSet.difference(expected, instances)
    only_in_result = MapSet.difference(instances, expected)
    assert MapSet.equal?(MapSet.new(), only_in_expected)
    assert MapSet.equal?(MapSet.new(), only_in_result)
  end

  # Execute this code to refresh the reference data for fetching instances test
  def refresh_discover_instances_test_data() do
    {:ok, {_videos, instances}} = PeertubeIndex.InstanceAPI.Httpc.scan("peertube.cpy.re", 5)
    File.write!(
      "test/peertube_index/instance_api_test_data/instances.json",
      Poison.encode!(MapSet.to_list(instances), pretty: true),
      [:binary, :write]
    )
  end

  test "unable to connect", %{bypass: bypass} do
    Bypass.down(bypass)
    result = PeertubeIndex.InstanceAPI.Httpc.scan("localhost:#{bypass.port}")
    assert result == {:error, {
      :failed_connect, [
        {:to_address, {'localhost', bypass.port}},
        {:inet, [:inet], :econnrefused}
      ]
    }}
  end

#  test "bad request" do
#
#  end

#  test "parse error" do
#
#  end

#  test "error after fist page" do
#
#  end

#  test "?visits all available pages" do
#
#  end
end
