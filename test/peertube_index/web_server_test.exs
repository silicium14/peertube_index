defmodule PeertubeIndex.WebServerTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @moduletag :integration

  @opts PeertubeIndex.WebServer.init([])

  test "ping works" do
    # Create a test connection
    conn = conn(:get, "/ping")

    # Invoke the plug
    conn = PeertubeIndex.WebServer.call(conn, @opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "pong"
  end

  test "unknown URL returns not found page" do
    conn = conn(:get, "/not_existing")

    conn = PeertubeIndex.WebServer.call(conn, @opts)

    assert conn.state == :sent
    assert conn.status == 404
    assert conn.resp_body == "Not found"
  end

  test "user can see home page" do
    conn = conn(:get, "/")

    conn = PeertubeIndex.WebServer.call(conn, @opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert List.keyfind(conn.resp_headers, "content-type", 0) == {"content-type", "text/html; charset=utf-8"}
  end

  test "user can search videos" do
    query = "the_user_search_text2"
    conn = conn(:get, "/search?text=#{query}")
    videos = []
    conn = assign(conn, :search_usecase_function, fn text ->
      send self(), {:search_function_called, text}
      videos
    end)
    conn = assign(conn, :render_page_function, fn videos, query ->
      send self(), {:render_function_called, videos, query}
      "Fake search result"
    end)

    # When a user does a search
    conn = PeertubeIndex.WebServer.call(conn, @opts)

    # Then the search use case is called with the user search text
    assert_received {:search_function_called, ^query}
    # And the search result is given to the page rendering
    assert_received {:render_function_called, ^videos, ^query}

    # Then he sees a response
    assert conn.state == :sent
    assert conn.status == 200
    assert List.keyfind(conn.resp_headers, "content-type", 0) == {"content-type", "text/html; charset=utf-8"}
    assert conn.resp_body == "Fake search result"
  end

  test "an empty search shows a validation error" do
    # When a user does a search with an empty text
    conn = conn(:get, "/search?text=")
    conn = assign(conn, :render_missing_text_function_called, fn ->
      send self(), {:render_missing_text_function_called}
      "Validation error"
    end)
    conn = PeertubeIndex.WebServer.call(conn, @opts)

    # Then the error page is rendered
    assert_received {:render_missing_text_function_called}

    # And the user sees the error
    assert conn.state == :sent
    assert conn.status == 400
    assert List.keyfind(conn.resp_headers, "content-type", 0) == {"content-type", "text/html; charset=utf-8"}
    assert conn.resp_body == "Validation error"
  end

  test "a missing search text query param shows a validation error" do
    # When a user does a search with an empty text
    conn = conn(:get, "/search")
    conn = assign(conn, :render_missing_text_function_called, fn ->
      send self(), {:render_missing_text_function_called}
      "Validation error"
    end)
    conn = PeertubeIndex.WebServer.call(conn, @opts)

    # Then the error page is rendered
    assert_received {:render_missing_text_function_called}

    # And the user sees the error
    assert conn.state == :sent
    assert conn.status == 400
    assert List.keyfind(conn.resp_headers, "content-type", 0) == {"content-type", "text/html; charset=utf-8"}
    assert conn.resp_body == "Validation error"
  end

  test "user can see about page" do
    conn = conn(:get, "/about")

    conn = PeertubeIndex.WebServer.call(conn, @opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert List.keyfind(conn.resp_headers, "content-type", 0) == {"content-type", "text/html; charset=utf-8"}
  end

  test "user can search videos as JSON" do
    query = "yet another user search text"
    conn = conn(:get, "/api/search?text=#{query}")
    videos = [
      %{"name" => "Some video"},
      %{"name" => "Some other video"}
    ]
    conn = assign(conn, :search_usecase_function, fn text ->
      send self(), {:search_function_called, text}
      videos
    end)

    # When a user does a search
    conn = PeertubeIndex.WebServer.call(conn, @opts)

    # Then the search use case is called with the user search text
    assert_received {:search_function_called, ^query}

    # Then he gets an ok reponse
    assert conn.state == :sent
    assert conn.status == 200
    assert List.keyfind(conn.resp_headers, "content-type", 0) == {"content-type", "application/json; charset=utf-8"}
    # And the response contains the search result
    assert Poison.decode!(conn.resp_body) == videos
  end
end
