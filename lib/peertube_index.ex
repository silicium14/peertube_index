defmodule PeertubeIndex do
  @moduledoc """
  PeerTube Index use cases
  """

  @storage Application.fetch_env!(:peertube_index, :storage)
  @instance_api Application.fetch_env!(:peertube_index, :instance_api)
  @status_storage Application.fetch_env!(:peertube_index, :status_storage)

#  TODO
#  - Better project structure
#  - Scan multiple instances concurrently
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
      {_, {videos, found_instances}} = @instance_api.scan(host)
      @storage.update_instance!(host, videos)
      @status_storage.new(host, :ok, get_local_time.())
      for instance <- found_instances, do: @status_storage.new(instance, :discovered, get_local_time.())
    end
  end
end
