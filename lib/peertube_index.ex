defmodule PeertubeIndex do
  @moduledoc """
  PeerTube Index use cases
  """

  require Logger

  @video_storage Application.fetch_env!(:peertube_index, :video_storage)
  @instance_scanner Application.fetch_env!(:peertube_index, :instance_scanner)
  @status_storage Application.fetch_env!(:peertube_index, :status_storage)

  @spec search(String.t) :: [map]
  def search(name) do
    @video_storage.search(name, nsfw: false)
  end

  @spec scan([String.t], (-> NaiveDateTime.t)) :: :ok
  def scan(hostnames, get_local_time \\ &get_current_time_naivedatetime/0) do
    banned_instances = @status_storage.find_instances(:banned)
    for host <- hostnames do
      if Enum.member?(banned_instances, host) do
        Logger.info "Skipping banned instance #{host}"
      else
        Logger.info "Scanning instance #{host}"
        result = @instance_scanner.scan(host)
        scan_end = get_local_time.()
        case result do
          {:ok, {videos, found_instances}} ->
            Logger.info "Scan successful for #{host}"
            @video_storage.delete_instance_videos!(host)
            @video_storage.insert_videos!(videos)
            @status_storage.ok_instance(host, scan_end)
            add_instances(found_instances, fn -> scan_end end)
          {:error, reason} ->
            Logger.info "Scan failed for #{host}, reason: #{inspect(reason)}"
            @status_storage.failed_instance(host, reason, scan_end)
            @video_storage.delete_instance_videos!(host)
        end
      end
    end

    :ok
  end

  @spec rescan((-> NaiveDateTime.t), ([String.t] -> :ok)) :: :ok
  def rescan(get_local_time \\ &get_current_time_naivedatetime/0, scan_function \\ &scan/1) do
    one_day_in_seconds = 24 * 60 * 60
    maximum_date = NaiveDateTime.add(get_local_time.(), - one_day_in_seconds)

    instances_to_rescan =
    @status_storage.find_instances(:discovered)
    ++ @status_storage.find_instances(:ok, maximum_date)
    ++ @status_storage.find_instances(:error, maximum_date)

    scan_function.(instances_to_rescan)
  end

  @spec ban_instance(String.t, String.t, (-> NaiveDateTime.t)) :: :ok
  def ban_instance(hostname, reason, get_local_time \\ &get_current_time_naivedatetime/0) do
    @video_storage.delete_instance_videos!(hostname)
    @status_storage.banned_instance(hostname, reason, get_local_time.())
    :ok
  end

  @spec remove_ban(String.t, (-> NaiveDateTime.t)) :: :ok
  def remove_ban(hostname, get_local_time \\ &get_current_time_naivedatetime/0) do
    @status_storage.discovered_instance(hostname, get_local_time.())
    :ok
  end

  @spec add_instances([String.t], (-> NaiveDateTime.t)) :: :ok
  def add_instances(hostnames, get_local_time \\ &get_current_time_naivedatetime/0) do
    current_time = get_local_time.()
    for hostname <- hostnames do
      if not @status_storage.has_a_status(hostname) do
        @status_storage.discovered_instance(hostname, current_time)
      end
    end
  end

  @spec get_current_time_naivedatetime :: NaiveDateTime.t
  defp get_current_time_naivedatetime do
    :calendar.local_time() |> NaiveDateTime.from_erl!()
  end
end
