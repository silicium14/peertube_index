defmodule PeertubeIndex.WebServer do
  @moduledoc false

  use Plug.Router

  plug Plug.Logger
  plug Plug.Static,
    at: "/static",
    from: "frontend/static"
  plug :match
  plug :dispatch

  get "/ping" do
    send_resp(conn, 200, "pong")
  end

  get "/" do
    conn = put_resp_content_type(conn, "text/html")
    send_resp(conn, 200, EEx.eval_file("frontend/home.html.eex", []))
  end

  get "/search" do
    search = conn.assigns[:search_usecase_function] || &PeertubeIndex.search/1
    render = conn.assigns[:render_page_function] || &render_search_page/2
    error_page = conn.assigns[:render_missing_text_function_called] || &render_missing_text_page/0

    conn = fetch_query_params(conn)
    query = conn.query_params["text"]
    case query do
      "" ->
        conn = put_resp_content_type(conn, "text/html")
        conn = put_resp_header(conn, "location", "/")
        send_resp(conn, 302, "")
      nil ->
        conn = put_resp_content_type(conn, "text/html")
        conn = put_resp_header(conn, "location", "/")
        send_resp(conn, 302, "")
      _ ->
        videos = search.(query)
        conn = put_resp_content_type(conn, "text/html")
        send_resp(conn, 200, render.(videos, query))
    end
  end

  defp render_search_page(videos, query) do
    EEx.eval_file("frontend/search.html.eex", [videos: videos, query: query])
  end

  defp render_missing_text_page do
    EEx.eval_file("templates/missing_text.html.eex")
  end

  get "/api/search" do
    search = conn.assigns[:search_usecase_function] || &PeertubeIndex.search/1

    conn = fetch_query_params(conn)
    videos = search.(Map.get(conn.query_params, "text"))
    conn = put_resp_content_type(conn, "application/json")
    send_resp(conn, 200, Poison.encode!(videos))
  end

  get "/about" do
    conn = put_resp_content_type(conn, "text/html")
    send_resp(conn, 200, EEx.eval_file("frontend/about.html.eex", []))
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
