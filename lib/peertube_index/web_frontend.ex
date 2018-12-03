defmodule PeertubeIndex.WebFrontend do
  @moduledoc false

  use Plug.Router

  plug :match
  plug :dispatch

  get "/ping" do
    send_resp(conn, 200, "pong")
  end

  get "" do
    conn = put_resp_content_type(conn, "text/html")
    send_resp(conn, 200, EEx.eval_file("templates/home.html.eex", []))
  end

  get "/search" do
    search = conn.assigns[:search_usecase_function] || &PeertubeIndex.search/1
    render = conn.assigns[:render_page_function] || &render_search_page/1

    conn = fetch_query_params(conn)
    videos = search.(conn.query_params["text"])
    conn = put_resp_content_type(conn, "text/html")
    send_resp(conn, 200, render.(videos))
  end

  defp render_search_page(videos) do
    EEx.eval_file("templates/search.html.eex", [videos: videos])
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
