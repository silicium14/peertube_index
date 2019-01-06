defmodule PeertubeIndex.WebFrontendTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @moduletag :integration

  @opts PeertubeIndex.WebFrontend.init([])

  test "ping works" do
    # Create a test connection
    conn = conn(:get, "/ping")

    # Invoke the plug
    conn = PeertubeIndex.WebFrontend.call(conn, @opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "pong"
  end

  test "unknown URL returns not found page" do
    conn = conn(:get, "/not_existing")

    conn = PeertubeIndex.WebFrontend.call(conn, @opts)

    assert conn.state == :sent
    assert conn.status == 404
    assert conn.resp_body == "Not found"
  end

  test "user can see home page" do
    conn = conn(:get, "")

    conn = PeertubeIndex.WebFrontend.call(conn, @opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert List.keyfind(conn.resp_headers, "content-type", 0) == {"content-type", "text/html; charset=utf-8"}
  end

  test "user can search videos" do
    conn = conn(:get, "/search?text=the_user_search_text2")
    videos = []
    conn = assign(conn, :search_usecase_function, fn text ->
      send self(), {:search_function_called, text}
      videos
    end)
    conn = assign(conn, :render_page_function, fn videos ->
      send self(), {:render_function_called, videos}
      "Fake search result"
    end)

    # When a user does a search
    conn = PeertubeIndex.WebFrontend.call(conn, @opts)

    # Then the search use case is called with the user search text
    assert_received {:search_function_called, "the_user_search_text2"}
    # And the search result is given to the page rendering
    assert_received {:render_function_called, ^videos}

    # Then he sees a reponse
    assert conn.state == :sent
    assert conn.status == 200
    assert List.keyfind(conn.resp_headers, "content-type", 0) == {"content-type", "text/html; charset=utf-8"}
    assert conn.resp_body == "Fake search result"
  end
end
