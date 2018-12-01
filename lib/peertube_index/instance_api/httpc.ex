defmodule PeertubeIndex.InstanceAPI.Httpc do
  @moduledoc false
  @behaviour PeertubeIndex.InstanceAPI
  require Logger

  @impl true
  def scan(host, page_size \\ 100, use_tls \\ true) do
    scheme = if use_tls, do: "https://", else: "http://"
    with {:ok, videos} <- get_all(scheme <> host <> "/api/v1/videos", page_size),
         {:ok, followers} = get_all(scheme <> host <> "/api/v1/server/followers", page_size),
         {:ok, following} = get_all(scheme <> host <> "/api/v1/server/following", page_size) do

      videos = Enum.filter(videos, fn video -> video["isLocal"] end)

      instances_from_videos = Enum.map(videos, fn video -> video["account"]["host"] end)
      instances_from_followers = Enum.map(followers, fn item -> item["follower"]["host"] end)
      instances_from_following = Enum.map(following, fn item -> item["following"]["host"] end)
      all_instances = instances_from_videos ++ instances_from_followers ++ instances_from_following

      unique_instances =
        all_instances
        |> MapSet.new()
        |> MapSet.delete(host)

      {:ok, {videos, unique_instances}}
    end
  end

  defp get_all(paginated_resource_url, page_size) do
    common_params = %{
      "count" => page_size,
      "sort" => "createdAt"
    }
    with {:ok, first_page_data} <- get_json(url_with_params(paginated_resource_url, common_params)) do
      number_of_pages = (first_page_data["total"] / page_size) |> Float.ceil() |> trunc()
      Logger.debug fn -> "Getting #{paginated_resource_url} that has #{first_page_data["total"]} items, using #{number_of_pages} pages" end
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
        {:error, :http_error}
      else
        {:ok, body}
      end
    end
  end

  defp get_json(url) do
    Logger.debug fn -> "Getting #{url}" end
    with {:ok, body} <- request_without_error(url),
         {:ok, parsed} <- Poison.decode(body),
         {:ok, validated} <- validate_page_data(parsed) do
      {:ok, validated}
    end
  end

  defp validate_page_data(page_data) do
    if is_integer(Map.get(page_data, "total")) and is_list(Map.get(page_data, "data")) do
      {:ok, page_data}
    else
      {:error, :page_invalid}
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
