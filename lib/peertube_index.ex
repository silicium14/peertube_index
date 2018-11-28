defmodule PeertubeIndex do
  @moduledoc """
  PeerTube Index use cases
  """

  @storage Application.fetch_env!(:peertube_index, :video_storage)
  @instance_api Application.fetch_env!(:peertube_index, :instance_api)
  @status_storage Application.fetch_env!(:peertube_index, :status_storage)

#  TODO
#  - Scan multiple instances concurrently
#  - Scan works with http and detects https or http
#  - Add task to seed status storage with known instance hosts
#  - We can see instances' status
#  - Search frontend
#  - Isolate and handle failures of the steps in scan function
#  - Refine search behaviour
#  - Use document type from Elasticsearch library?
#  - Remember that in the domain we directly use the objects returned by the storage without any conversion, we are coupled to the storage format for now

  @spec search(String.t) :: [map]
  def search(name) do
    @storage.search(name)
  end

  @spec scan([String.t], (-> NaiveDateTime.t)) :: :ok
  def scan(hostnames, get_local_time \\ &get_current_time_naivedatetime/0) do
    for host <- hostnames do
      result = @instance_api.scan(host)
      scan_end = get_local_time.()
      case result do
        {:ok, {videos, found_instances}} ->
          @storage.update_instance!(host, videos)
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
