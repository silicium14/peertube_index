defmodule PeertubeIndex.HttpApi do
  @moduledoc false

  use Plug.Router

  plug :match
  plug :dispatch

  get "/search" do
    search = conn.assigns[:search_usecase_function] || &PeertubeIndex.search/3
#    deserialize = conn.assigns[:deserialize_input_function] || &deserialize/1

    conn = fetch_query_params(conn)
    search_result = search.(conn.query_params |> Map.get("text"), conn.query_params |> Map.get("page_size", "10") |> Integer.parse() |> elem(0), conn.query_params |> Map.get("page", "1") |> Integer.parse() |> elem(0))
    conn = put_resp_content_type(conn, "application/json")
    send_resp(conn, 200, Poison.encode!(search_result))
#    case deserialize.(conn.query_params) do
#      {:ok, parsed_params} ->
#        search_result = search.(parsed_params["text"], parsed_params["page_size"], parsed_params["page"])
#        conn = put_resp_content_type(conn, "application/json")
#        send_resp(conn, 200, Poison.encode!(search_result))
#      {:error, errors} ->
#        conn = put_resp_content_type(conn, "application/json")
#        send_resp(conn, 400, Poison.encode!(errors))
#    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

#  def deserialize(input_data) do
#    errors = %{}
##    parsed_params = %{}
##    {parsed_params, errors} =
##    if Map.has_key?(input_data, "text") do
##      {Map.put(parsed_params, "text", input_data["text"]), errors}
##    else
##      {parsed_params, Map.put(errors, "text", "Must be present")}
##    end
#
#    {page_size, _} = input_data |> Map.get("page_size", "10") |> Integer.parse()
#    {page, _} = input_data |> Map.get("page", "1") |> Integer.parse()
#    if map_size(errors) > 0 do
#      {:error, errors}
#    else
#      {:ok, %{
#        "page_size" => page_size,
#        "page" => page,
#        "text" => Map.get(input_data, "text")
#      }}
#    end
#  end
end
