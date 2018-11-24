defmodule PeertubeIndexTest do
  use ExUnit.Case, async: true


  test "we can search a video by its name using storage" do
    # Given there are videos
    a_cat_video = %{"name" => "A video about a cat"}
    Mox.expect(
      PeertubeIndex.VideoStorage.Mock, :search,
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
    Mox.stub(PeertubeIndex.StatusStorage.Mock, :new, fn _host, _status, _date -> :ok end)

    videos = [%{"name" => "some video"}]
    Mox.expect(PeertubeIndex.InstanceAPI.Mock, :scan, fn "some-instance.example.com" -> {:ok, {videos, MapSet.new()}} end)
    Mox.expect( PeertubeIndex.VideoStorage.Mock, :update_instance!, fn "some-instance.example.com", ^videos -> :ok end)

    videos = [%{"name" => "some other video"}]
    Mox.expect(PeertubeIndex.InstanceAPI.Mock, :scan, fn "some-other-instance.example.com" -> {:ok, {videos, MapSet.new()}} end)
    Mox.expect(PeertubeIndex.VideoStorage.Mock, :update_instance!, fn "some-other-instance.example.com", ^videos -> :ok end)

    PeertubeIndex.scan(["some-instance.example.com", "some-other-instance.example.com"])

    Mox.verify!()
  end

  test "scan updates instance status" do
    Mox.stub(PeertubeIndex.InstanceAPI.Mock, :scan, fn "some-instance.example.com" -> {:ok, {[], MapSet.new()}} end)
    Mox.stub(PeertubeIndex.VideoStorage.Mock, :update_instance!, fn "some-instance.example.com", _videos -> :ok end)
    finishes_at = {{2018, 1, 1}, {14, 15, 16}}
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :new, fn "some-instance.example.com", :ok, ^finishes_at -> :ok end)


    PeertubeIndex.scan(["some-instance.example.com"], fn -> finishes_at end)

    Mox.verify!()
  end

  test "scan reports the appropriate status for discovered instances" do
    Mox.stub(
      PeertubeIndex.InstanceAPI.Mock, :scan,
      fn "some-instance.example.com" ->
        {:ok, {[], MapSet.new(["found-instance.example.com", "another-found-instance.example.com"])}}
      end
    )
    Mox.stub(PeertubeIndex.VideoStorage.Mock, :update_instance!, fn "some-instance.example.com", _videos -> :ok end)
    finishes_at = {{2018, 1, 1}, {14, 15, 16}}
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :new, fn "some-instance.example.com", :ok, ^finishes_at -> :ok end)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :new, fn "another-found-instance.example.com", :discovered, ^finishes_at -> :ok end)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :new, fn "found-instance.example.com", :discovered, ^finishes_at -> :ok end)


    PeertubeIndex.scan(["some-instance.example.com"], fn -> finishes_at end)

    Mox.verify!()
  end

  test "scan handles failures and reports the corresponding statuses" do
    Mox.stub(PeertubeIndex.InstanceAPI.Mock, :scan, fn "some-instance.example.com" -> {:error, :reason} end)
    finishes_at = {{2018, 1, 1}, {14, 15, 16}}
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :new, fn "some-instance.example.com", {:error, :reason}, ^finishes_at -> :ok end)

    PeertubeIndex.scan(["some-instance.example.com"], fn -> finishes_at end)

    Mox.verify!()
  end
end
