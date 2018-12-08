defmodule PeertubeIndex.HttpApiTest do
  use ExUnit.Case, async:
  use Plug.Test

  @moduletag :integration


  @opts PeertubeIndex.HttpApi.init([])

  test "unknown URL returns not found page" do
    conn = conn(:get, "/not_existing")

    conn = PeertubeIndex.HttpApi.call(conn, @opts)

    assert conn.state == :sent
    assert conn.status == 404
    assert conn.resp_body == "Not found"
  end

  test "user can search videos" do
    conn = conn(:get, "/search?text=the_user_search_text")
    search_result = %{
      "videos" => [%{"name" => "Some video"}, %{"name" => "Some other video"}]
    }
    conn = assign(conn, :search_usecase_function, fn text ->
      send self(), {:search_function_called, text}
      search_result
    end)

    # When a user does a search
    conn = PeertubeIndex.HttpApi.call(conn, @opts)

    # Then the search use case is called with the user search text
    assert_received {:search_function_called, "the_user_search_text"}

    # Then he gets an ok reponse
    assert conn.state == :sent
    assert conn.status == 200
    assert List.keyfind(conn.resp_headers, "content-type", 0) == {"content-type", "application/json; charset=utf-8"}
    # And the response contains the search result
    assert Poison.decode!(conn.resp_body) == search_result
  end
end
