defmodule PeertubeIndex.StatusStorage.Filesystem do
  @moduledoc false

  @behaviour PeertubeIndex.StatusStorage
  @directory Application.fetch_env!(:peertube_index, :status_storage_directory)

  @impl true
  def empty() do
    File.rm_rf(@directory)
    File.mkdir!(@directory)
  end

  @impl true
  def with_statuses(statuses) do
    empty()
    for status <- statuses do
      case status do
        {host, :ok, date} ->
          write_status_map(host, %{"host" => host, "status" => "ok", "date" => date})
        {host, {:error, reason}, date} ->
          write_status_map(host, %{"host" => host, "status" => "error", "reason" => inspect(reason), "date" => date})
        {host, :discovered, date} ->
          write_status_map(host, %{"host" => host, "status" => "discovered", "date" => date})
      end
    end

    :ok
  end

  @impl true
  def all() do
    for file <- File.ls!(@directory) do
      {:ok, bytes} = :file.read_file("#{@directory}/#{file}")
      status_map = Poison.decode!(bytes)
      case status_map do
        %{"host" => host, "status" => "discovered", "date" => date_string} ->
          {host, :discovered, NaiveDateTime.from_iso8601!(date_string)}
        %{"host" => host, "status" => "ok", "date" => date_string} ->
          {host, :ok, NaiveDateTime.from_iso8601!(date_string)}
        %{"host" => host, "status" => "error", "reason" => reason_string, "date" => date_string} ->
          {host, {:error, reason_string}, NaiveDateTime.from_iso8601!(date_string)}
      end
    end
  end
  
  @impl true
  def instances_to_rescan(get_current_time \\ &get_current_time_naivedatetime/0) do
    current_instant = get_current_time.()

    all()
    |> Enum.filter(fn {_host, status, date} -> should_we_rescan?(status, date, current_instant) end)
    |> Enum.map(fn {host, _status, _date} -> host end)
    |> Enum.to_list()
  end

  defp should_we_rescan?(:discovered, _date, _current_instant), do: true
  defp should_we_rescan?(_ok_or_error, date, current_instant) do
    NaiveDateTime.diff(current_instant, date) > (24 * 60 * 60)
  end

  defp get_current_time_naivedatetime() do
    {{year, month, day}, {hour, minute, second}} = :calendar.local_time()
    {:ok, current_time} = NaiveDateTime.new(year, month, day, hour, minute, second)
    current_time
  end

  @impl true
  def ok_instance(host, date) do
    write_status_map(host, %{"host" => host, "status" => "ok", "date" => date})
  end

  @impl true
  def failed_instance(host, reason, date) do
    write_status_map(host, %{"host" => host, "status" => "error", "reason" => inspect(reason), "date" => date})
  end

  @impl true
  def discovered_instance(host, date) do
    if has_no_already_existing_status(host) do
      write_status_map(host, %{"host" => host, "status" => "discovered", "date" => date})
    end
  end

  defp write_status_map(host, status_map) do
    {:ok, file} = :file.open(host_file(host), [:raw, :write])
    :file.write(file, Poison.encode!(status_map, pretty: true))
    :file.close(file)
  end

  def has_no_already_existing_status(host) do
    host
    |> host_file()
    |> File.exists?()
    |> Kernel.not()
  end

  defp host_file(host) do
    "#{@directory}/#{host}.json"
  end
end
