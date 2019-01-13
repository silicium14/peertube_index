defmodule PeertubeIndex.InstanceApiTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open
    {:ok, bypass: bypass}
  end

  test "unable to connect", %{bypass: bypass} do
    Bypass.down(bypass)
    result = PeertubeIndex.InstanceAPI.Http.scan("localhost:#{bypass.port}")
    assert result == {:error, {
      :failed_connect, [
        {:to_address, {'localhost', bypass.port}},
        {:inet, [:inet], :econnrefused}
      ]
    }}
  end

  defp empty_instance do
    %{
      {"GET", "/api/v1/videos"} => {
        :stub, fn conn ->
          Plug.Conn.resp(conn, 200, ~s<{"total": 0, "data": []}>)
        end},
      {"GET", "/api/v1/server/followers"} => {
          :stub, fn conn ->
            Plug.Conn.resp(conn, 200, ~s<{"total": 0, "data": []}>)
          end},
      {"GET", "/api/v1/server/following"} => {
          :stub, fn conn ->
            Plug.Conn.resp(conn, 200, ~s<{"total": 0, "data": []}>)
          end}
    }
  end

  defp overwrite_expectation(routes, type, method, path, function) do
    Map.put(routes, {method, path}, {type, function})
  end

  defp apply_bypass(routes, bypass) do
    for {{method, path}, {expect_function, function}} <- routes do
      case expect_function do
        :stub ->
          Bypass.stub(bypass, method, path, function)
        :expect ->
          Bypass.expect(bypass, method, path, function)
        :expect_once ->
          Bypass.expect_once(bypass, method, path, function)
        invalid ->
          raise "Invalid expect function #{invalid}"
      end
    end
  end

  defp empty_instance_but(bypass, expect_function, method, path, function) do
    empty_instance()
    |> overwrite_expectation(expect_function, method, path, function)
    |> apply_bypass(bypass)
  end

  test "bad HTTP status", %{bypass: bypass} do
    empty_instance_but(bypass, :expect_once, "GET", "/api/v1/videos", &Plug.Conn.resp(&1, 400, "{}"))
    result = PeertubeIndex.InstanceAPI.Http.scan("localhost:#{bypass.port}", 100, false)
    assert result == {:error, :http_error}
  end

  test "JSON parse error", %{bypass: bypass} do
    empty_instance_but(bypass, :expect_once, "GET", "/api/v1/videos", &Plug.Conn.resp(&1, 200, "invalid JSON document"))
    result = PeertubeIndex.InstanceAPI.Http.scan("localhost:#{bypass.port}", 100, false)
    assert result == {:error, %Poison.ParseError{pos: 0, rest: nil, value: "i"}}
  end

  test "error after fist page", %{bypass: bypass} do
    empty_instance_but(bypass, :expect, "GET", "/api/v1/videos", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      response = if Map.has_key?(conn.query_params, "start") do
        ~s<bad json>
      else
        ~s<{"total": 10, "data": []}>
      end
      Plug.Conn.resp(conn, 200, response)
    end)

    {status, _} = PeertubeIndex.InstanceAPI.Http.scan("localhost:#{bypass.port}", 5, false)
    assert status == :error
  end

  test "error on followers", %{bypass: bypass} do
    empty_instance_but(bypass, :expect, "GET", "/api/v1/server/followers", &Plug.Conn.resp(&1, 500, "Error"))
    result = PeertubeIndex.InstanceAPI.Http.scan("localhost:#{bypass.port}", 100, false)
    assert result == {:error, :http_error}
  end

  test "error on following", %{bypass: bypass} do
    empty_instance_but(bypass, :expect, "GET", "/api/v1/server/following", &Plug.Conn.resp(&1, 500, "Error"))
    result = PeertubeIndex.InstanceAPI.Http.scan("localhost:#{bypass.port}", 100, false)
    assert result == {:error, :http_error}
  end

  test "gets all videos correctly with a single page", %{bypass: bypass} do
    empty_instance_but(bypass, :expect, "GET", "/api/v1/videos", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      Plug.Conn.resp(conn, 200, ~s<{
        "total": 2,
        "data": [
          {"id": 0, "isLocal": true},
          {"id": 1, "isLocal": true}
        ]
      }>)
    end)

    {:ok, {videos, _instances}} = PeertubeIndex.InstanceAPI.Http.scan("localhost:#{bypass.port}", 10, false)
    assert videos == [
      %{"id" =>  0, "isLocal" => true},
      %{"id" =>  1, "isLocal" => true}
    ]
  end

  test "gets all videos correctly with pagination", %{bypass: bypass} do
    empty_instance_but(bypass, :expect, "GET", "/api/v1/videos", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      start = Map.get(conn.query_params, "start", "0")
      Plug.Conn.resp(conn, 200, ~s<{"total": 3, "data": [{"id": #{start}, "isLocal": true}]}>)
    end)

    {:ok, {videos, _instances}} = PeertubeIndex.InstanceAPI.Http.scan("localhost:#{bypass.port}", 1, false)
    assert videos == [
      %{"id" =>  0, "isLocal" => true},
      %{"id" =>  1, "isLocal" => true},
      %{"id" =>  2, "isLocal" => true}
    ]
  end

  test "wrong page format", %{bypass: bypass} do
    empty_instance_but(bypass, :expect, "GET", "/api/v1/videos", &Plug.Conn.resp(&1, 200, "{\"not the correct format\": \"some value\"}"))
    result = PeertubeIndex.InstanceAPI.Http.scan("localhost:#{bypass.port}", 100, false)
    assert result == {:error, :page_invalid}
  end

  test "can timeout on requests", %{bypass: bypass} do
    reponse_delay = 600
    empty_instance_but(bypass, :expect, "GET", "/api/v1/videos", fn conn ->
      Process.sleep(reponse_delay)
      Plug.Conn.resp(conn, 200, ~s<{"total": 0, "data": []}>)
    end)

    result = PeertubeIndex.InstanceAPI.Http.scan("localhost:#{bypass.port}", 100, false, reponse_delay - 100)
    assert result == {:error, :timeout}
  end

  @tag skip: "TODO"
  test "ensures TLS validity"
  @tag skip: "TODO"
  test "discover new instances"
end
