defmodule PeertubeIndex do
  @moduledoc """
  PeerTube Index use cases
  """

  @storage Application.fetch_env!(:peertube_index, :video_storage)
  @instance_api Application.fetch_env!(:peertube_index, :instance_api)
  @status_storage Application.fetch_env!(:peertube_index, :status_storage)

#  TODO
#  - Better project structure
#  - Document at least InstanceAPI behaviour
#  - Scan multiple instances concurrently
#  - Scan works with http and detects https or http
#  - Save instance status
#  - Use case tests
#  - Update from status database
#  - We can see instances' status
#  - Search frontend
#  - Use document type from Elasticsearch library?
#  - Remember that in the domain we directly use the objects returned by the storage without any conversion, we are coupled to the storage format for now

  def search(name) do
    @storage.search(name)
  end

  def scan(hostnames, get_local_time \\ &:calendar.local_time/0) do
    for host <- hostnames do
      result = @instance_api.scan(host)
      scan_end = get_local_time.()
      case result do
        {:ok, {videos, found_instances}} ->
          @storage.update_instance!(host, videos)
          @status_storage.new_status(host, :ok, scan_end)
          for instance <- found_instances, do: @status_storage.new_status(instance, :discovered, scan_end)
        {:error, reason} ->
          @status_storage.new_status(host, {:error, reason}, scan_end)
      end
    end
  end

  def rescan(get_local_time \\ &:calendar.local_time/0, scan_function \\ &scan/1) do
    @status_storage.instances_to_rescan(get_local_time.())
    |> scan_function.()
  end
end
