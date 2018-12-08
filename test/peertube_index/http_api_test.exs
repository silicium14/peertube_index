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
      "total_count" => 2,
      "videos" => [%{"name" => "Some video"}, %{"name" => "Some other video"}]
    }
    conn = assign(conn, :search_usecase_function, fn text, page_size, page ->
      send self(), {:search_function_called, text, page_size, page}
      search_result
    end)

    # When a user does a search
    conn = PeertubeIndex.HttpApi.call(conn, @opts)

    # Then the search use case is called with the user search text
    assert_received {:search_function_called, "the_user_search_text", 10, 1}

    # Then he gets an ok reponse
    assert conn.state == :sent
    assert conn.status == 200
    assert List.keyfind(conn.resp_headers, "content-type", 0) == {"content-type", "application/json; charset=utf-8"}
    # And the response contains the search result
    assert Poison.decode!(conn.resp_body) == search_result
  end

  test "user can search videos with pagination" do
    conn = conn(:get, "/search?text=some_search&page_size=20&page=2")
    search_result = %{
      "total_count" => 2,
      "videos" => [%{"name" => "Some video"}, %{"name" => "Some other video"}]
    }
    conn = assign(conn, :search_usecase_function, fn text, page_size, page ->
      send self(), {:search_function_called, text, page_size, page}
      search_result
    end)

    # When a user does a search
    conn = PeertubeIndex.HttpApi.call(conn, @opts)

    # Then the search use case is called with the user search text
    assert_received {:search_function_called, "some_search", 20, 2}

    # Then he gets an ok reponse
    assert conn.state == :sent
    assert conn.status == 200
    assert List.keyfind(conn.resp_headers, "content-type", 0) == {"content-type", "application/json; charset=utf-8"}
    # And the response contains the search result
    assert Poison.decode!(conn.resp_body) == search_result
  end

#  test "validates inputs and returns validation errors" do
#    conn = conn(:get, "/search?text=a_search_text&page_size=invalid&page=2")
#    conn = assign(conn, :search_usecase_function, fn _text, _page_size, _page ->
#      raise "Search use case should not be called"
#    end)
#    conn = assign(conn, :deserialize_input_function, fn input_data ->
#      send self(), {:deserialize_input_function_called, input_data}
#      {:error, %{"page_size" => "Must be an integer"}}
#    end)
#
#    conn = PeertubeIndex.HttpApi.call(conn, @opts)
#
#    assert_received {
#      :deserialize_input_function_called,
#      %{"text" => "a_search_text", "page_size" => "invalid", "page" => "2"}
#    }
#
#    assert conn.state == :sent
#    assert conn.status == 400
#    assert List.keyfind(conn.resp_headers, "content-type", 0) == {"content-type", "application/json; charset=utf-8"}
#    assert Poison.decode!(conn.resp_body) == %{"page_size" => "Must be an integer"}
#  end
#
#  describe "deserialize" do
#    test "text" do
#      {:error, errors} = PeertubeIndex.HttpApi.deserialize(%{})
#      assert Map.get(errors, "text") == "Must be present"
#
#      {:ok, parsed_params} = PeertubeIndex.HttpApi.deserialize(%{"text" => "some_text"})
#      assert parsed_params["text"] == "some_text"
#    end
#  end
end
