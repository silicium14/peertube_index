defmodule PeertubeIndex do
  @moduledoc """
  PeerTube Index use cases
  """

  @storage Application.fetch_env!(:peertube_index, :storage)
  @instance_api Application.fetch_env!(:peertube_index, :instance_api)

#  TODO
#  - Better project structure
#  - Save instance status
#  - Use case tests
#  - Test instance API
#  - Update from status database
#  - Search frontend
#  - Use document type from Elasticsearch library?
#  - Remember that in the domain we directly use the objects returned by the storage without any conversion, we are coupled to the storage format for now

  def search(name) do
    @storage.search(name)
  end

  def scan(hostnames) do
    for host <- hostnames do
      {:ok, {videos, _}} = @instance_api.scan(host)
      @storage.update_instance!(host, videos)
    end
  end

end
