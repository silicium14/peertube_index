defmodule PeertubeIndexTest do
  use ExUnit.Case, async: true


  test "we can search a video by its name using storage" do
    # Given there are videos
    a_cat_video = %{"name" => "A video about a cat"}
    Mox.expect(
      PeertubeIndex.Storage.Mock, :search,
      # Then The storage is asked for the correct term
      fn "cat" ->
        [a_cat_video]
      end
    )

    # When the user searches for a video name
    videos = PeertubeIndex.search("cat")

    # Then the storage is asked for matching videos
    Mox.verify!()
    # And the matching videos are returned
    assert videos == [a_cat_video]
  end

  test "scan uses instance api and updates instances in storage" do
    videos = [%{"name" => "some video"}]
    Mox.expect(PeertubeIndex.InstanceAPI.Mock, :scan, fn "some-instance.example.com" -> {videos, MapSet.new()} end)
    Mox.expect( PeertubeIndex.Storage.Mock, :update_instance!, fn "some-instance.example.com", ^videos -> :ok end)

    videos = [%{"name" => "some other video"}]
    Mox.expect(PeertubeIndex.InstanceAPI.Mock, :scan, fn "some-other-instance.example.com" -> {videos, MapSet.new()} end)
    Mox.expect(PeertubeIndex.Storage.Mock, :update_instance!, fn "some-other-instance.example.com", ^videos -> :ok end)

    PeertubeIndex.scan(["some-instance.example.com", "some-other-instance.example.com"])

    Mox.verify!()
  end

#  test "scan logs failures in a file" do
#    Mox.expect(
#      PeertubeIndex.InstanceAPI.Mock, :scan,
#      fn "failing-instance.example.com" -> raise "Failing on purpose for the test" end
#    )
#
#    PeertubeIndex.scan(["failing-instance.example.com"])
#
#    Mox.verify!()
#  end
end
