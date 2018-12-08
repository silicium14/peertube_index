defmodule PeertubeIndex.HttpApi do
  @moduledoc false

  use Plug.Router

  plug :match
  plug :dispatch

  get "/search" do
    search = conn.assigns[:search_usecase_function] || &PeertubeIndex.search/1

    conn = fetch_query_params(conn)
    search_result = search.(Map.get(conn.query_params, "text"))
    conn = put_resp_content_type(conn, "application/json")
    send_resp(conn, 200, Poison.encode!(search_result))
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
