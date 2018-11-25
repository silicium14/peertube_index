defmodule PeertubeIndex.StatusStorageTest do
  use ExUnit.Case

  @moduletag :integration

  test "status reporting functions create entries when instances have no status yet" do
    PeertubeIndex.StatusStorage.Filesystem.empty()

    PeertubeIndex.StatusStorage.Filesystem.ok_instance("example.com", ~N[2018-01-02 15:50:00])
    PeertubeIndex.StatusStorage.Filesystem.failed_instance("other.example.com", {:some_error_reason, "arbitrary error data"}, ~N[2018-01-03 16:20:00])
    PeertubeIndex.StatusStorage.Filesystem.discovered_instance("newly-discovered.example.com", ~N[2018-02-05 10:00:00])

    assert MapSet.new(PeertubeIndex.StatusStorage.Filesystem.all()) == MapSet.new([
             {"example.com", :ok, ~N[2018-01-02 15:50:00]},
             {"other.example.com", {:error, inspect({:some_error_reason, "arbitrary error data"})}, ~N[2018-01-03 16:20:00]},
             {"newly-discovered.example.com", :discovered, ~N[2018-02-05 10:00:00]}
           ])
  end
end
