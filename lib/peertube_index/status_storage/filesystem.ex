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
  def new_status(host, status, date) do
    {:ok, file} = :file.open("#{@directory}/#{host}.json", [:raw, :write])
    status_map =
    case status do
      :discovered ->
        %{"host" => host, "status" => "discovered", "date" => date}
      :ok ->
        %{"host" => host, "status" => "ok", "date" => date}
      {:error, reason} ->
        %{"host" => host, "status" => "error", "reason" => inspect(reason), "date" => date}
    end
    :file.write(file, Poison.encode!(status_map, pretty: true))
    :file.close(file)
  end
end
