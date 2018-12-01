defmodule PeertubeIndex.InstanceAPITest do
  use ExUnit.Case, async: true

  @moduletag :integration

  setup do
    bypass = Bypass.open
    {:ok, bypass: bypass}
  end

  # TODO: ignore changes in demo instance for tests OR use our own test instance

  test "scan gives the same videos" do
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

  test "scan gives the same instances" do
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

  test "bad HTTP status", %{bypass: bypass} do
    Bypass.expect_once bypass, "GET", "/api/v1/videos", fn conn ->
      Plug.Conn.resp(conn, 400, "{}")
    end
    result = PeertubeIndex.InstanceAPI.Httpc.scan("localhost:#{bypass.port}", 100, false)
    assert result == {:error, :http_error}
  end

  test "JSON parse error", %{bypass: bypass} do
    Bypass.expect_once bypass, "GET", "/api/v1/videos", fn conn ->
      Plug.Conn.resp(conn, 200, "invalid JSON document")
    end

    result = PeertubeIndex.InstanceAPI.Httpc.scan("localhost:#{bypass.port}", 100, false)
    assert result == {:error, %Poison.ParseError{pos: 0, rest: nil, value: "i"}}
  end

  test "error after fist page", %{bypass: bypass}do
    Bypass.expect bypass, "GET", "/api/v1/videos", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      response = if Map.has_key?(conn.query_params, "start") do
        ~s<bad json>
      else
        ~s<{"total": 10, "data": []}>
      end
      Plug.Conn.resp(conn, 200, response)
    end

    {status, _} = PeertubeIndex.InstanceAPI.Httpc.scan("localhost:#{bypass.port}", 5, false)
    assert status == :error
  end

  test "gets all videos correctly with a single page", %{bypass: bypass} do
    Bypass.expect bypass, "GET", "/api/v1/videos", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      Plug.Conn.resp(conn, 200, ~s<{"total": 2, "data": [{"id": 0, "isLocal": true}, {"id": 1, "isLocal": true}]}>)
    end

    Bypass.stub bypass, "GET", "/api/v1/server/followers", fn conn ->
      Plug.Conn.resp(conn, 200, ~s<{"total": 0, "data": []}>)
    end

    Bypass.stub bypass, "GET", "/api/v1/server/following", fn conn ->
      Plug.Conn.resp(conn, 200, ~s<{"total": 0, "data": []}>)
    end

    {:ok, {videos, _instances}} = PeertubeIndex.InstanceAPI.Httpc.scan("localhost:#{bypass.port}", 10, false)
    assert videos == [
             %{"id" =>  0, "isLocal" => true},
             %{"id" =>  1, "isLocal" => true}
           ]
  end

  test "gets all videos correctly with pagination", %{bypass: bypass} do
    Bypass.expect bypass, "GET", "/api/v1/videos", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      start = Map.get(conn.query_params, "start", "0")
      Plug.Conn.resp(conn, 200, ~s<{"total": 3, "data": [{"id": #{start}, "isLocal": true}]}>)
    end

    Bypass.stub bypass, "GET", "/api/v1/server/followers", fn conn ->
      Plug.Conn.resp(conn, 200, ~s<{"total": 0, "data": []}>)
    end

    Bypass.stub bypass, "GET", "/api/v1/server/following", fn conn ->
      Plug.Conn.resp(conn, 200, ~s<{"total": 0, "data": []}>)
    end

    {:ok, {videos, _instances}} = PeertubeIndex.InstanceAPI.Httpc.scan("localhost:#{bypass.port}", 1, false)
    assert videos == [
             %{"id" =>  0, "isLocal" => true},
             %{"id" =>  1, "isLocal" => true},
             %{"id" =>  2, "isLocal" => true}
           ]
  end

  test "wrong page format", %{bypass: bypass} do
    Bypass.expect_once bypass, "GET", "/api/v1/videos", fn conn ->
      Plug.Conn.resp(conn, 200, "{\"not the correct format\": \"some value\"}")
    end

    result = PeertubeIndex.InstanceAPI.Httpc.scan("localhost:#{bypass.port}", 100, false)
    assert result == {:error, :page_invalid}
  end

end
