defmodule PeertubeIndex.InstanceAPI.Httpc do
  @moduledoc false

  @behaviour PeertubeIndex.InstanceAPI

  @impl true
  def scan(host, page_size \\ 100, use_tls \\ true) do
    scheme = if use_tls, do: "https://", else: "http://"
    with {:ok, videos} <- get_all(scheme <> host <> "/api/v1/videos", page_size),
         {:ok, followers} = get_all(scheme <> host <> "/api/v1/server/followers", page_size),
         {:ok, following} = get_all(scheme <> host <> "/api/v1/server/following", page_size) do

      instances =
        MapSet.new(
          Enum.map(videos, fn video -> video["account"]["host"] end) ++
          Enum.map(followers, fn item -> item["follower"]["host"] end) ++
          Enum.map(following, fn item -> item["following"]["host"] end)
        )
        |> MapSet.delete(host)

      videos = Enum.filter(videos, fn video -> video["isLocal"] end)

      {:ok, {videos, instances}}
    end
  end

  defp get_all(paginated_resource_url, page_size) do
    common_params = %{
      "count" => page_size,
      "sort" => "createdAt"
    }
    with {:ok, first_page_data} <- get_json(url_with_params(paginated_resource_url, common_params)) do
      number_of_pages = (first_page_data["total"] / page_size) |> Float.ceil() |> trunc()
      if number_of_pages > 1 do
        urls = for page_number <- 2..number_of_pages do
          url_with_params(
            paginated_resource_url,
            Map.put(common_params, "start", (page_number - 1) * page_size)
          )
        end
        get_recursive(urls, first_page_data["data"])
      else
        {:ok, first_page_data["data"]}
      end
    end
  end

  defp get_recursive([next_url | rest], results) do
    with {:ok, page_data} <- get_json(next_url) do
      get_recursive(rest, results ++ page_data["data"])
    end
  end

  defp get_recursive([], results), do: {:ok, results}

  defp request_without_error(url) do
    with {:ok, {
             {_http_version, status_code, _reason_phrase}, _headers, body
         }} <- :httpc.request(:get, {String.to_charlist(url), []}, [], body_format: :binary) do
      if status_code >= 400 do
        {:error, :bad_request}
      else
        {:ok, body}
      end
    end
  end

  defp get_json(url) do
    with {:ok, body} <- request_without_error(url),
         {:ok, parsed} <- Poison.decode(body) do
      {:ok, parsed}
    end
  end

  defp url_with_params(url, params) do
    params_fragment =
      params
      |> Map.to_list
      |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
      |> Enum.join("&")

    url <> "?" <> params_fragment
  end

end
