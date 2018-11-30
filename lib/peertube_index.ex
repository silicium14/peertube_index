defmodule PeertubeIndex do
  @moduledoc """
  PeerTube Index use cases
  """

  require Logger

  @video_storage Application.fetch_env!(:peertube_index, :video_storage)
  @instance_api Application.fetch_env!(:peertube_index, :instance_api)
  @status_storage Application.fetch_env!(:peertube_index, :status_storage)


  @spec search(String.t) :: [map]
  def search(name) do
    @video_storage.search(name)
  end

  @spec scan([String.t], (-> NaiveDateTime.t)) :: :ok
  def scan(hostnames, get_local_time \\ &get_current_time_naivedatetime/0) do
    for host <- hostnames do
      Logger.info "Scanning instance #{host}"
      result = @instance_api.scan(host)
      scan_end = get_local_time.()
      case result do
        {:ok, {videos, found_instances}} ->
          Logger.info "Scan successful for #{host} with #{length(videos)} videos and #{MapSet.size(found_instances)} instances"
          @video_storage.update_instance!(host, videos)
          @status_storage.ok_instance(host, scan_end)
          for instance <- found_instances, do: @status_storage.discovered_instance(instance, scan_end)
        {:error, reason} ->
          @status_storage.failed_instance(host, reason, scan_end)
      end
    end

    :ok
  end

  @spec rescan((-> NaiveDateTime.t), ([String.t] -> :ok)) :: :ok
  def rescan(get_local_time \\ &get_current_time_naivedatetime/0, scan_function \\ &scan/1) do
    @status_storage.instances_to_rescan(get_local_time.())
    |> scan_function.()
  end

  @spec get_current_time_naivedatetime() :: NaiveDateTime.t
  defp get_current_time_naivedatetime() do
    {{year, month, day}, {hour, minute, second}} = :calendar.local_time()
    {:ok, current_time} = NaiveDateTime.new(year, month, day, hour, minute, second)
    current_time
  end
end
