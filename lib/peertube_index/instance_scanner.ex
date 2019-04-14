defmodule PeertubeIndex.InstanceScanner do
  @moduledoc false

  @callback scan(String.t, integer, boolean, integer) :: {:ok, {Enumerable.t, MapSet.t}} | {:error, any()}
  # With default arguments
  @callback scan(String.t) :: {:ok, {Enumerable.t, MapSet.t}} | {:error, any()}
end

defmodule PeertubeIndex.InstanceScanner.Http do
  @moduledoc false
  @behaviour PeertubeIndex.InstanceScanner
  require Logger

  @impl true
  def scan(host, page_size \\ 100, use_tls \\ true, request_timeout \\ 5000) do
    scheme = if use_tls, do: "https://", else: "http://"
    api_base_url = scheme <> host <> "/api/v1/"
    with {:ok, instances_from_followers} <- get_instances_from_followers(api_base_url <> "server/followers", page_size, request_timeout),
         {:ok, instances_from_following} <- get_instances_from_following(api_base_url <> "server/following", page_size, request_timeout),
         {:ok, videos, instances_from_videos} <- get_videos(api_base_url <> "videos", page_size, request_timeout) do

      instances =
      instances_from_videos
      |> MapSet.union(instances_from_followers)
      |> MapSet.union(instances_from_following)
      |> MapSet.delete(host)

      {:ok, {videos, instances}}
    end
  end

  defp get_instances_from_following(following_url, page_size, request_timeout) do
    following_url
    |> get_collection(page_size, request_timeout)
    |> Enum.reduce_while(
         {:ok, MapSet.new()},
         reducer_while_no_error(fn following, set_of_instances ->
           MapSet.put(set_of_instances, following["following"]["host"])
         end)
       )
  end

  defp get_instances_from_followers(followers_url, page_size, request_timeout) do
    followers_url
    |> get_collection(page_size, request_timeout)
    |> reduce_enum_while_no_error(MapSet.new(), fn follower, set_of_instances -> MapSet.put(set_of_instances, follower["follower"]["host"]) end)
  end

  @doc """
  Fetches videos with streaming, saves the result on a file on disk
  and returns a stream to read the videos from disk.
  Also returns a set instances found in the videos.
  """
  @spec get_videos(String.t, integer, integer) :: {:ok, Stream.t, MapSet.t}
  defp get_videos(videos_url, page_size, request_timeout) do
    buffer_file_path = "video_buffer"
    buffer_file = File.open!(buffer_file_path, [:binary, :write])

    result_of_processing =
    videos_url
    |> get_collection(page_size, request_timeout) # {:ok, video} or {:error, page_error}
    |> Stream.map(&validate_one_video_and_keep_errors/1) # {:ok, video} or {:error, page_error} or :error, :invalid_video_document}
    |> reduce_enum_while_no_error({buffer_file, MapSet.new()}, &save_videos_and_reduce_instances/2)

    File.close(buffer_file)

    case result_of_processing do
      {:ok, {_buffer_file, instances}} ->
        {
          :ok,
          Stream.resource(
            fn -> File.open!(buffer_file_path, [:binary, :read]) end,
            &read_next_video/1,
            fn buffer_file ->
              :ok = File.close(buffer_file)
              :ok = File.rm(buffer_file_path)
            end
          ),
          instances
        }
      {:error, reason} ->
        File.rm(buffer_file_path)
        {:error, reason}
    end
  end

  @doc """
  Iterate over the stream of videos and
  - compute the set of instances found from the videos
  - save videos to disk, excluding non local videos

  The following format is used for serializing the collection of videos
  start_of_file
  [size_as_text,newline
  term_as_binary,newline] repeated as many times as needed
  end_of_file

  size_as_text: the string representation of the binary size of term_as_binary, if term_as_binary is 152 bytes long, then size_as_text is the string 152
  newline: a line jump character, \n
  term_as_binary: the bytes given by :erlang.term_to_binary
  """
  defp save_videos_and_reduce_instances(video = %{"isLocal" => true}, {buffer_file, instances}) do
    # Save video to disk
    term_binary = :erlang.term_to_binary(video)
    size_field = term_binary |> byte_size() |> Integer.to_string()
    IO.binwrite(buffer_file, size_field <> "\n" <> term_binary <> "\n")

    # Add instance
    instances = MapSet.put(instances, video["account"]["host"])

    {buffer_file, instances}
  end

  defp save_videos_and_reduce_instances(video = %{"isLocal" => false}, {buffer_file, instances}) do
    # Just add instance
    instances = MapSet.put(instances, video["account"]["host"])
    {buffer_file, instances}
  end

  defp read_next_video(buffer_file) do
    case IO.binread(buffer_file, :line) do
      line when is_binary(line) ->
        {size, _} = Integer.parse(line)
        item = buffer_file |> IO.binread(size) |> :erlang.binary_to_term()
        IO.binread(buffer_file, 1) # Read newline
        {[item], buffer_file}
      :eof ->
        {:halt, buffer_file}
    end
  end

  defp request_with_timeout(url, timeout) do
    request = Task.async(fn ->
      :httpc.request(
        :get,
        {String.to_charlist(url), []},
        [],
        body_format: :binary)
    end)
    case Task.yield(request, timeout) || Task.shutdown(request) do
      {:ok, httpc_result} ->
        {:ok, httpc_result}
      nil ->
        {:error, :timeout}
    end
  end

  defp request_successful(response) do
    with {:ok, {
      {_http_version, status_code, _reason_phrase}, _headers, body
    }} <- response do
      if status_code >= 400 do
        {:error, :http_error}
      else
        {:ok, body}
      end
    end
  end

  defp validate_page_data(page_data) do
    if is_integer(Map.get(page_data, "total")) and is_list(Map.get(page_data, "data")) do
      {:ok, page_data}
    else
      {:error, :page_invalid}
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp valid_video?(video) do
    video |> Map.get("id") |> is_integer
    && video |> Map.get("uuid") |> is_binary
    && video |> Map.get("name") |> is_binary
    && video |> Map.get("category") |> is_map
    && (
      video |> get_in(["category", "id"]) |> is_nil
      || video |> get_in(["category", "id"]) |> is_integer
    )
    && video |> get_in(["category", "label"]) |> is_binary
    && video |> Map.get("licence") |> is_map
    && (
      video |> get_in(["licence", "id"]) |> is_nil
      || video |> get_in(["licence", "id"]) |> is_integer
    )
    && video |> get_in(["licence", "label"]) |> is_binary
    && video |> Map.get("language") |> is_map
    && (
      video |> get_in(["language", "id"]) |> is_nil
      || video |> get_in(["language", "id"]) |> is_binary
    )
    && video |> get_in(["language", "label"]) |> is_binary
    && video |> Map.get("privacy") |> is_map
    && video |> get_in(["privacy", "id"]) |> is_integer
    && video |> get_in(["privacy", "label"]) |> is_binary
    && video |> Map.get("nsfw") |> is_boolean
    && (
      video |> Map.get("description") |> is_nil
      || video |> Map.get("description") |> is_binary
    )
    && video |> Map.get("isLocal") |> is_boolean
    && video |> Map.get("duration") |> is_integer
    && video |> Map.get("views") |> is_integer
    && video |> Map.get("likes") |> is_integer
    && video |> Map.get("dislikes") |> is_integer
    && video |> Map.get("thumbnailPath") |> is_binary
    && video |> Map.get("previewPath") |> is_binary
    && video |> Map.get("embedPath") |> is_binary
    && video |> Map.get("createdAt") |> is_binary # Validate date format?
    && video |> Map.get("updatedAt") |> is_binary # Validate date format?
    && video |> Map.get("publishedAt") |> is_binary # Validate date format?
    && video |> Map.get("account") |> is_map
    && video |> get_in(["account", "id"]) |> is_integer
    && video |> get_in(["account", "uuid"]) |> is_binary
    && video |> get_in(["account", "name"]) |> is_binary
    && video |> get_in(["account", "displayName"]) |> is_binary
    && video |> get_in(["account", "url"]) |> is_binary
    && video |> get_in(["account", "host"]) |> is_binary
    && (
      video |> get_in(["account", "avatar"]) |> is_nil
      || (
        video |> get_in(["account", "avatar"]) |> is_map
        && video |> get_in(["account", "avatar", "path"]) |> is_binary
        && video |> get_in(["account", "avatar", "createdAt"]) |> is_binary # Validate date format?
        && video |> get_in(["account", "avatar", "updatedAt"]) |> is_binary # Validate date format?
      )
    )
    && video |> Map.get("channel") |> is_map
    && video |> get_in(["channel", "id"]) |> is_integer
    && video |> get_in(["channel", "uuid"]) |> is_binary
    && video |> get_in(["channel", "name"]) |> is_binary
    && video |> get_in(["channel", "displayName"]) |> is_binary
    && video |> get_in(["channel", "url"]) |> is_binary
    && video |> get_in(["channel", "host"]) |> is_binary
    && (
      video |> get_in(["channel", "avatar"]) |> is_nil
      || (
        video |> get_in(["channel", "avatar"]) |> is_map
        && video |> get_in(["channel", "avatar", "path"]) |> is_binary
        && video |> get_in(["channel", "avatar", "createdAt"]) |> is_binary # Validate date format?
        && video |> get_in(["channel", "avatar", "updatedAt"]) |> is_binary # Validate date format?
      )
    )
  end

  defp get_page(url, request_timeout) do
    Logger.debug fn -> "Getting #{url}" end
    with {:ok, httpc_result} <- request_with_timeout(url, request_timeout),
         {:ok, body} <- request_successful(httpc_result),
         {:ok, parsed} <- Poison.decode(body),
         {:ok, parsed} <- validate_page_data(parsed) do
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

  defp generate_urls_after_first_page(paginated_collection_url, common_params, page_size, number_of_pages) do
    for page_number <- 2..number_of_pages do
      url_with_params(
        paginated_collection_url,
        Map.put(common_params, "start", (page_number - 1) * page_size)
      )
    end
  end

  defp validate_one_video_and_keep_errors({:ok, video}) do
    if valid_video?(video) do
      {:ok, video}
    else
      {:error, :invalid_video_document}
    end
  end

  defp validate_one_video_and_keep_errors({:error, reason}) do
    {:error, reason}
  end

  @doc """
  Returns an stream of ok/error tuples for each item of the collection: {:ok, item} or {:error, reason}.
  The errors that my be present are about the page fetching steps.
  For example, with a page size of 2 items and 3 pages, if there was an http error on the second page, the output would be :
  `[{:ok, item}, {:ok, item}, {:error, :http_error}, {:ok, item}, {:ok, item}]`
  """
  @spec get_collection(String.t, integer(), integer()) :: Stream.t
  defp get_collection(paginated_collection_url, page_size, request_timeout) do
    paginated_collection_url
    |> get_pages(page_size, request_timeout) # {:ok, page} or {:error, reason}
    |> Stream.flat_map(&extract_page_items_and_keep_errors/1) # {:ok, video} or {:error, reason}
  end

  @doc """
  Returns an enumerable of ok/error tuples for each page: {:ok, page_data} or {:error, reason}
  If there is a single page the result is a list.
  If there is more than one page the result is a stream.
  """
  @spec get_pages(String.t, integer(), integer()) :: Enum.t
  defp get_pages(paginated_collection_url, page_size, request_timeout) do
    common_params = %{
      "count" => page_size,
      "sort" => "createdAt"
    }
    with {:ok, first_page} <- get_page(url_with_params(paginated_collection_url, common_params), request_timeout) do
      # credo:disable-for-next-line Credo.Check.Refactor.PipeChainStart
      number_of_pages = (first_page["total"] / page_size) |> Float.ceil() |> trunc()
      Logger.debug fn -> "#{paginated_collection_url} has #{first_page["total"]} items, using #{number_of_pages} pages" end
      if number_of_pages > 1 do
        urls = generate_urls_after_first_page(paginated_collection_url, common_params, page_size, number_of_pages)
        Stream.concat(
          [{:ok, first_page}],
          Stream.map(urls, fn url -> get_page(url, request_timeout) end)
        )
      else
        [{:ok, first_page}]
      end
    else
      {:error, reason} ->
        [{:error, reason}]
    end
  end

  defp extract_page_items_and_keep_errors({:ok, page}) do
    for item <- page["data"] do
      {:ok, item}
    end
  end

  defp extract_page_items_and_keep_errors({:error, reason}) do
    [{:error, reason}]
  end

  #####

  # The accumulator is {:ok, real_accumulator} because the expected output is
  # {:ok, value} or {:error, reason}
  defp reduce_while_no_error({:ok, element}, {:ok, accumulator}, reducer) do
    {
      :cont,
      {:ok, reducer.(element, accumulator)}
    }
  end

  defp reduce_while_no_error({:error, reason}, {:ok, _accumulator}, _reducer) do
    {:halt, {:error, reason}}
  end

  # reducer: (element, accumulator -> accumulator)
  @spec reducer_while_no_error(
          (any(), any() -> any())
  ) :: ({:ok, any()} | {:error, any()}, {:ok, any()} -> {:cont, {:ok, any()}} | {:halt, {:error, any()}})
  defp reducer_while_no_error(reducer) do
    fn element, accumulator -> reduce_while_no_error(element, accumulator, reducer) end
  end

  @doc """
  Reduces an enumerable whose elements are either {:ok, element} or {:error, reason}
  and stops if at the first {:error, reason} found.

  The reducer function receives the second element of each tuple.

  If an error is found, is is returned as is.
  If no error is found, the returned value is {:ok, accumulator}.
  """
  @spec reduce_enum_while_no_error(Enumerable.t, any(), (any(), any() -> any())) :: {:ok, any()} | {:error, any()}
  defp reduce_enum_while_no_error(enum, acc, fun) do
    Enum.reduce_while(enum, {:ok, acc}, reducer_while_no_error(fun))
  end
end
