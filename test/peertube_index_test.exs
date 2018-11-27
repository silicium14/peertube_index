defmodule PeertubeIndexTest do
  use ExUnit.Case, async: true


  test "we can search a videos by their name using storage" do
    # Given there are videos
    a_video = %{"name" => "A video about a cat"}
    another_video = %{"name" => "A video about a cats and dogs"}
    Mox.expect(
      PeertubeIndex.VideoStorage.Mock, :search,
      # Then The storage is asked for the correct term
      fn "cat" ->
        [a_video, another_video]
      end
    )

    # When the user searches for a video name
    videos = PeertubeIndex.search("cat")

    # Then the storage is asked for matching videos
    Mox.verify!()
    # And the matching videos are returned in the same order as returned by the storage
    assert videos == [a_video, another_video]
  end

  test "scan uses instance api and updates instances in storage" do
    Mox.stub(PeertubeIndex.StatusStorage.Mock, :ok_instance, fn _host, _date -> :ok end)

    videos = [%{"name" => "some video"}]
    Mox.expect(PeertubeIndex.InstanceAPI.Mock, :scan, fn "some-instance.example.com" -> {:ok, {videos, MapSet.new()}} end)
    Mox.expect(PeertubeIndex.VideoStorage.Mock, :update_instance!, fn "some-instance.example.com", ^videos -> :ok end)

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
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :ok_instance, fn "some-instance.example.com", ^finishes_at -> :ok end)


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
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :ok_instance, fn "some-instance.example.com", ^finishes_at -> :ok end)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :discovered_instance, fn "another-found-instance.example.com", ^finishes_at -> :ok end)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :discovered_instance, fn "found-instance.example.com", ^finishes_at -> :ok end)


    PeertubeIndex.scan(["some-instance.example.com"], fn -> finishes_at end)

    Mox.verify!()
  end

  test "scan handles failures and reports the corresponding statuses" do
    Mox.stub(PeertubeIndex.InstanceAPI.Mock, :scan, fn "some-instance.example.com" -> {:error, :reason} end)
    finishes_at = {{2018, 1, 1}, {14, 15, 16}}
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :failed_instance, fn "some-instance.example.com", :reason, ^finishes_at -> :ok end)

    PeertubeIndex.scan(["some-instance.example.com"], fn -> finishes_at end)

    Mox.verify!()
  end

  test "rescan scans instances to rescan" do
    current_time = {{2018, 1, 1}, {14, 15, 16}}
    instances_to_rescan = ["some-instance.example.com", "another-instance.example.com"]
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :instances_to_rescan, fn ^current_time -> instances_to_rescan end)
    PeertubeIndex.rescan(fn -> current_time end, fn instances -> send self(), {:scan_function_called, [instances]} end)
    Mox.verify!()
    assert_received {:scan_function_called, [instances_to_rescan]}
  end
end
