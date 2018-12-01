defmodule ToClean do
  @moduledoc false

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

  def get_all(_host) do
    []
  end

  def scan_one_instance(_host) do
    []
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
    |> Stream.each(fn {hostname, _status, {_instances, videos}} -> update_one_instance!(hostname, videos) end)
    |> Enum.to_list()
  end

  def inspect_to_file(term) do
    {:ok, file} = :file.open("inspect.exs", [:raw, :write])
    :file.write(file, inspect(term, pretty: true))
    :file.close(file)
  end

  def update_one_instance!(_hostnames, _videos) do
  end

end
