defmodule PeertubeIndex.InstanceScannerTest do
  use ExUnit.Case, async: false

  @valid_video %{
    "id"=> 1,
    "uuid"=> "00000000-0000-0000-0000-000000000000",
    "name"=> "This is the video name",
    "category"=> %{
      "id"=> 15,
      "label"=> "Science & Technology"
    },
    "licence"=> %{
      "id"=> 4,
      "label"=> "Attribution - Non Commercial"
    },
    "language"=> %{
      "id"=> nil,
      "label"=> "Unknown"
    },
    "privacy"=> %{
      "id"=> 1,
      "label"=> "Public"
    },
    "nsfw"=> false,
    "description"=> "This is the video description",
    "isLocal"=> true,
    "duration"=> 274,
    "views"=> 1696,
    "likes"=> 29,
    "dislikes"=> 0,
    "thumbnailPath"=> "/static/thumbnails/00000000-0000-0000-0000-000000000000.jpg",
    "previewPath"=> "/static/previews/00000000-0000-0000-0000-000000000000.jpg",
    "embedPath"=> "/videos/embed/00000000-0000-0000-0000-000000000000",
    "createdAt"=> "2018-08-02T13:47:17.515Z",
    "updatedAt"=> "2019-02-12T05:01:00.587Z",
    "publishedAt"=> "2018-08-02T13:55:13.338Z",
    "account"=> %{
      "id"=> 501,
      "uuid"=> "00000000-0000-0000-0000-000000000000",
      "name"=> "user",
      "displayName"=> "user",
      "url"=> "https://peertube.example.com/accounts/user",
      "host"=> "peertube.example.com",
      "avatar"=> %{
        "path"=> "/static/avatars/00000000-0000-0000-0000-000000000000.jpg",
        "createdAt"=> "2018-08-02T10:56:25.627Z",
        "updatedAt"=> "2018-08-02T10:56:25.627Z"
      }
    },
    "channel"=> %{
      "id"=> 23,
      "uuid"=> "00000000-0000-0000-0000-000000000000",
      "name"=> "00000000-0000-0000-0000-000000000000",
      "displayName"=> "Default user channel",
      "url"=> "https://peertube.example.com/video-channels/00000000-0000-0000-0000-000000000000",
      "host"=> "peertube.example.com",
      "avatar"=> %{
        "path"=> "/static/avatars/00000000-0000-0000-0000-000000000000.jpg",
        "createdAt"=> "2018-08-02T10:56:25.627Z",
        "updatedAt"=> "2018-08-02T10:56:25.627Z"
      }
    }
  }

  setup do
    bypass = Bypass.open
    {:ok, bypass: bypass}
  end

  test "unable to connect", %{bypass: bypass} do
    Bypass.down(bypass)
    result = PeertubeIndex.InstanceScanner.Http.scan("localhost:#{bypass.port}")
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

  @doc """
  Create bypass responses for an empty instance and overwrite one route with the given arguments
  """
  defp empty_instance_but(bypass, expect_function, method, path, function) do
    empty_instance()
    |> overwrite_expectation(expect_function, method, path, function)
    |> apply_bypass(bypass)
  end

  test "bad HTTP status", %{bypass: bypass} do
    empty_instance_but(bypass, :expect_once, "GET", "/api/v1/videos", &Plug.Conn.resp(&1, 400, "{}"))
    result = PeertubeIndex.InstanceScanner.Http.scan("localhost:#{bypass.port}", 100, false)
    assert result == {:error, :http_error}
  end

  test "JSON parse error", %{bypass: bypass} do
    empty_instance_but(bypass, :expect_once, "GET", "/api/v1/videos", &Plug.Conn.resp(&1, 200, "invalid JSON document"))
    result = PeertubeIndex.InstanceScanner.Http.scan("localhost:#{bypass.port}", 100, false)
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

    {status, _} = PeertubeIndex.InstanceScanner.Http.scan("localhost:#{bypass.port}", 5, false)
    assert status == :error
  end

  test "error on followers", %{bypass: bypass} do
    empty_instance_but(bypass, :expect, "GET", "/api/v1/server/followers", &Plug.Conn.resp(&1, 500, "Error"))
    result = PeertubeIndex.InstanceScanner.Http.scan("localhost:#{bypass.port}", 100, false)
    assert result == {:error, :http_error}
  end

  test "error on following", %{bypass: bypass} do
    empty_instance_but(bypass, :expect, "GET", "/api/v1/server/following", &Plug.Conn.resp(&1, 500, "Error"))
    result = PeertubeIndex.InstanceScanner.Http.scan("localhost:#{bypass.port}", 100, false)
    assert result == {:error, :http_error}
  end

  test "gets all videos correctly with a single page", %{bypass: bypass} do
    a_video = @valid_video |> Map.put("id", 0)
    another_video = @valid_video |> Map.put("id", 1)

    empty_instance_but(bypass, :expect, "GET", "/api/v1/videos", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      Plug.Conn.resp(conn, 200, ~s<{
        "total": 2,
        "data": [
          #{a_video |> Poison.encode!()},
          #{another_video |> Poison.encode!()}
        ]
      }>)
    end)

    {:ok, {videos, _instances}} = PeertubeIndex.InstanceScanner.Http.scan("localhost:#{bypass.port}", 10, false)
    assert videos == [a_video, another_video]
  end

  test "gets all videos correctly with pagination", %{bypass: bypass} do
    empty_instance_but(bypass, :expect, "GET", "/api/v1/videos", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      {start, ""} = conn.query_params |> Map.get("start", "0") |> Integer.parse()
      Plug.Conn.resp(conn, 200, ~s<{
        "total": 3,
        "data": [
          #{@valid_video |> Map.put("id", start) |> Poison.encode!()}
        ]
      }>)
    end)

    {:ok, {videos, _instances}} = PeertubeIndex.InstanceScanner.Http.scan("localhost:#{bypass.port}", 1, false)
    assert videos == [
      @valid_video |> Map.put("id", 0),
      @valid_video |> Map.put("id", 1),
      @valid_video |> Map.put("id", 2)
    ]
  end

  test "wrong page format", %{bypass: bypass} do
    empty_instance_but(bypass, :expect, "GET", "/api/v1/videos", &Plug.Conn.resp(&1, 200, "{\"not the correct format\": \"some value\"}"))
    result = PeertubeIndex.InstanceScanner.Http.scan("localhost:#{bypass.port}", 100, false)
    assert result == {:error, :page_invalid}
  end

  test "validates incoming video documents", %{bypass: bypass} do
    invalid_video = Map.delete(@valid_video, "account")
    empty_instance_but(bypass, :expect, "GET", "/api/v1/videos", fn conn ->
      Plug.Conn.resp(
        conn,
        200,
        ~s<
        {
          "total": 2,
          "data": [
            #{Poison.encode!(@valid_video)},
            #{Poison.encode!(invalid_video)}
          ]
        }
        >
      )
    end)
    result = PeertubeIndex.InstanceScanner.Http.scan("localhost:#{bypass.port}", 100, false)
    assert result == {:error, :invalid_video_document}
  end

  test "can timeout on requests", %{bypass: bypass} do
    reponse_delay = 600
    empty_instance_but(bypass, :expect, "GET", "/api/v1/videos", fn conn ->
      Process.sleep(reponse_delay)
      Plug.Conn.resp(conn, 200, ~s<{"total": 0, "data": []}>)
    end)

    result = PeertubeIndex.InstanceScanner.Http.scan("localhost:#{bypass.port}", 100, false, reponse_delay - 100)
    assert result == {:error, :timeout}
  end


  test "discovers new instances from videos", %{bypass: bypass} do
    hostname = "localhost:#{bypass.port}"
    a_video =
    @valid_video
    |>Map.put("id", 0)
    |> put_in(["account", "host"], hostname)
    |> put_in(["channel", "host"], hostname)

    another_video =
    @valid_video
    |> Map.put("id", 1)
    |> put_in(["account", "host"], "new-instance.example.com")
    |> put_in(["channel", "host"], "new-instance.example.com")

    empty_instance_but(bypass, :expect, "GET", "/api/v1/videos", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      Plug.Conn.resp(conn, 200, ~s<{
        "total": 2,
        "data": [
          #{a_video |> Poison.encode!()},
          #{another_video |> Poison.encode!()}
        ]
      }>)
    end)

    {:ok, {_videos, instances}} = PeertubeIndex.InstanceScanner.Http.scan(hostname, 10, false)
    # The returned instances does not contain the instance being scanned
    assert instances == MapSet.new(["new-instance.example.com"])
  end

  test "discovers new instances from following", %{bypass: bypass} do
    empty_instance_but(bypass, :expect, "GET", "/api/v1/server/following", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      Plug.Conn.resp(conn, 200, ~s<{
        "total": 1,
        "data": [
          {"following": {"host": "new-instance.example.com"}},
          {"following": {"host": "another-new-instance.example.com"}}
        ]
      }>)
    end)

    {:ok, {_videos, instances}} = PeertubeIndex.InstanceScanner.Http.scan("localhost:#{bypass.port}", 10, false)
    assert instances == MapSet.new(["new-instance.example.com", "another-new-instance.example.com"])
  end

  test "discovers new instances from followers", %{bypass: bypass} do
    empty_instance_but(bypass, :expect, "GET", "/api/v1/server/followers", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      Plug.Conn.resp(conn, 200, ~s<{
        "total": 1,
        "data": [
          {"follower": {"host": "new-instance.example.com"}},
          {"follower": {"host": "another-new-instance.example.com"}}
        ]
      }>)
    end)

    {:ok, {_videos, instances}} = PeertubeIndex.InstanceScanner.Http.scan("localhost:#{bypass.port}", 10, false)
    assert instances == MapSet.new(["new-instance.example.com", "another-new-instance.example.com"])
  end

  test "excludes non local videos", %{bypass: bypass} do
    local_video = @valid_video |> Map.put("id", 0)
    non_local_video =
    @valid_video
    |> Map.put("id", 1)
    |> Map.put("isLocal", false)
    |> put_in(["channel", "host"], "other-instance.example.com")
    |> put_in(["account", "host"], "other-instance.example.com")

    empty_instance_but(bypass, :expect, "GET", "/api/v1/videos", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      Plug.Conn.resp(conn, 200, ~s<{
        "total": 2,
        "data": [
          #{local_video |> Poison.encode!()},
          #{non_local_video |> Poison.encode!()}
        ]
      }>)
    end)

    {:ok, {videos, _instances}} = PeertubeIndex.InstanceScanner.Http.scan("localhost:#{bypass.port}", 10, false)
    assert videos == [local_video]
  end


  @tag skip: "TODO"
  test "ensures TLS validity"
end
