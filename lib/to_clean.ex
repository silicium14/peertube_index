defmodule ToClean do

  use Application

  def start(_type, _args) do
    PeertubeIndex.Supervisor.start_link(name: PeertubeIndex.Supervisor)
  end

  def get_json(url) do
    {:ok, {{_, status_code, _} = status, _headers, body}} =
      :httpc.request(
        :get,
        {String.to_charlist(url), []},
        [],
        body_format: :binary
      )

    if status_code >= 400 do
      raise "HTTP error for URL #{inspect(url)}: status=#{inspect(status)}"
    end

    Poison.decode!(body)
  end

  def url_with_params(url, params) do
    params_fragment =
      params
      |> Map.to_list
      |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
      |> Enum.join("&")

    url <> "?" <> params_fragment
  end

  def get_all(paginated_resource_url) do
    page_size = 100
    common_params = %{
      "count" => page_size,
      "sort" => "createdAt"
    }

    first_page_data = get_json(url_with_params(paginated_resource_url, common_params))
    number_of_pages = (first_page_data["total"] / page_size) |> Float.ceil() |> trunc() |> max(1)

    1..number_of_pages
    |> Enum.drop(1)
    |> Enum.map(fn page_number ->
      {page_number,
        url_with_params(paginated_resource_url, Map.put(common_params, "start", (page_number - 1) * page_size))}
    end)
    |> Enum.reduce(
      first_page_data["data"],
      fn {_page_number, page_url}, accumulator ->
#        IO.puts("#{page_url}, page #{page_number}/#{number_of_pages}")
        accumulator ++ get_json(page_url)["data"]
      end
    )
  end

  def scan_one_instance(host) do
#    IO.puts("[#{host}] Fetching videos")
    videos = get_all("https://" <> host <> "/api/v1/videos")
#    IO.puts("[#{host}] Fetching followers")
    followers = get_all("https://" <> host <> "/api/v1/server/followers")
#    IO.puts("[#{host}] Fetching following")
    following = get_all("https://" <> host <> "/api/v1/server/following")

    instances =
      Enum.uniq(
        Enum.map(videos, fn video -> video["account"]["host"] end) ++
        Enum.map(followers, fn item -> item["follower"]["host"] end) ++
        Enum.map(following, fn item -> item["following"]["host"] end)
      )

    videos = Enum.filter(videos, fn video -> video["isLocal"] end)

    {instances, videos}
  end

  def update_instance_to_file({hostname, :ok, {_instances, videos}}) do
    {:ok, file} = :file.open("database/#{hostname}.json", [:raw, :write])
    :file.write(file, Poison.encode!(videos, pretty: true))
    :file.close(file)
  end

  def update_instance_to_file({_hostname, _status, _data}) do
  end

  def log_failures({_hostname, :ok, _data}) do
  end

  def log_failures({hostname, _status, _error} = result) do
    {:ok, file} = :file.open("failed/#{hostname}.log", [:raw, :write])
    :file.write(file, inspect(result, pretty: true))
    :file.close(file)
  end

  def log_progress(stream, total) do
    stream
    |> Stream.with_index()
    |> Stream.each(fn {_item, index} -> IO.puts("Scanned #{index + 1}/#{total}") end)
    |> Stream.map(fn {item, _index} -> item end)
  end

  def scan() do
    instances =
      get_all("https://instances.joinpeertube.org/api/v1/instances")
      |> Enum.sort_by(fn instance -> instance["totalVideos"] end)
      |> Enum.map(fn instance -> instance["host"] end)


    total = length(instances)

    task_stream =
      Task.Supervisor.async_stream_nolink(
        PeertubeIndex.ScanningSupervisor,
        instances,
        &scan_one_instance/1,
        ordered: true,
        timeout: 5_000,
        on_timeout: :kill_task,
        max_concurrency: System.schedulers_online() * 8
      )

    Stream.zip(instances, task_stream)
    |> Stream.map(fn {hostname, {status, data}} -> {hostname, status, data} end)
    |> log_progress(total)
    |> Stream.each(&log_failures/1)
    |> Stream.filter(fn {_hostname, status, _data} -> status == :ok end)
    |> Stream.each(fn {hostname, _status, {_instances, videos}} -> PeertubeIndex.Storage.Elasticsearch.update_instance!(hostname, videos) end)
    |> Enum.to_list()
  end

  def inspect_to_file(term) do
    {:ok, file} = :file.open("inspect.exs", [:raw, :write])
    :file.write(file, inspect(term, pretty: true))
    :file.close(file)
  end

end
