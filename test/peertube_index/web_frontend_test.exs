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
end
