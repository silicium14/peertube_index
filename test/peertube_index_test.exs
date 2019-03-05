defmodule PeertubeIndexTest do
  use ExUnit.Case, async: true

  test "we can search safe videos by their name using storage" do
    # Given there are videos
    a_video = %{"name" => "A video about a cat"}
    another_video = %{"name" => "A video about a cats and dogs"}
    Mox.expect(
      PeertubeIndex.VideoStorage.Mock, :search,
      # Then The storage is asked for the correct term and safety
      fn "cat", nsfw: false ->
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

  test "scan uses instance api, deletes existing instance videos and inserts new ones in video storage" do
    Mox.stub(PeertubeIndex.StatusStorage.Mock, :find_instances, fn :banned -> [] end)
    Mox.stub(PeertubeIndex.StatusStorage.Mock, :ok_instance, fn _host, _date -> :ok end)

    videos = [%{"name" => "some video"}]
    Mox.expect(PeertubeIndex.InstanceScanner.Mock, :scan, fn "some-instance.example.com" -> {:ok, {videos, MapSet.new()}} end)
    Mox.expect(PeertubeIndex.VideoStorage.Mock, :delete_instance_videos!, fn "some-instance.example.com" -> :ok end)
    Mox.expect(PeertubeIndex.VideoStorage.Mock, :update_instance!, fn "some-instance.example.com", ^videos -> :ok end)

    videos = [%{"name" => "some other video"}]
    Mox.expect(PeertubeIndex.InstanceScanner.Mock, :scan, fn "some-other-instance.example.com" -> {:ok, {videos, MapSet.new()}} end)
    Mox.expect(PeertubeIndex.VideoStorage.Mock, :delete_instance_videos!, fn "some-other-instance.example.com" -> :ok end)
    Mox.expect(PeertubeIndex.VideoStorage.Mock, :update_instance!, fn "some-other-instance.example.com", ^videos -> :ok end)

    PeertubeIndex.scan(["some-instance.example.com", "some-other-instance.example.com"])

    Mox.verify!()
  end

  test "scan updates instance status" do
    Mox.stub(PeertubeIndex.StatusStorage.Mock, :find_instances, fn :banned -> [] end)
    Mox.stub(PeertubeIndex.InstanceScanner.Mock, :scan, fn "some-instance.example.com" -> {:ok, {[], MapSet.new()}} end)
    Mox.stub(PeertubeIndex.VideoStorage.Mock, :delete_instance_videos!, fn hostname -> :ok end)
    Mox.stub(PeertubeIndex.VideoStorage.Mock, :update_instance!, fn "some-instance.example.com", _videos -> :ok end)
    {:ok, finishes_at} = NaiveDateTime.new(2018, 1, 1, 14, 15, 16)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :ok_instance, fn "some-instance.example.com", ^finishes_at -> :ok end)

    PeertubeIndex.scan(["some-instance.example.com"], fn -> finishes_at end)

    Mox.verify!()
  end

  test "scan reports the appropriate status for discovered instances" do
    Mox.stub(PeertubeIndex.StatusStorage.Mock, :find_instances, fn :banned -> [] end)
    Mox.stub(
      PeertubeIndex.InstanceScanner.Mock, :scan,
      fn "some-instance.example.com" ->
        {:ok, {[], MapSet.new(["found-instance.example.com", "another-found-instance.example.com"])}}
      end
    )
    Mox.stub(PeertubeIndex.VideoStorage.Mock, :delete_instance_videos!, fn hostname -> :ok end)
    Mox.stub(PeertubeIndex.VideoStorage.Mock, :update_instance!, fn hostname, videos -> :ok end)
    {:ok, finishes_at} = NaiveDateTime.new(2018, 1, 1, 14, 15, 16)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :ok_instance, fn "some-instance.example.com", ^finishes_at -> :ok end)
    # Discovered instances do not have a status yet
    Mox.stub(PeertubeIndex.StatusStorage.Mock, :has_a_status, fn hostname -> false end)

    # Then we set the status for the discovered instances
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :discovered_instance, fn "another-found-instance.example.com", ^finishes_at -> :ok end)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :discovered_instance, fn "found-instance.example.com", ^finishes_at -> :ok end)

    PeertubeIndex.scan(["some-instance.example.com"], fn -> finishes_at end)

    Mox.verify!()
  end

  test "scan handles failures, reports the corresponding statuses and deletes existing videos for the failed instance" do
    Mox.stub(PeertubeIndex.StatusStorage.Mock, :find_instances, fn :banned -> [] end)
    Mox.stub(PeertubeIndex.InstanceScanner.Mock, :scan, fn "some-instance.example.com" -> {:error, :some_reason} end)
    Mox.expect(PeertubeIndex.VideoStorage.Mock, :delete_instance_videos!, fn "some-instance.example.com" -> :ok end)
    {:ok, finishes_at} = NaiveDateTime.new(2018, 1, 1, 14, 15, 16)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :failed_instance, fn "some-instance.example.com", :some_reason, ^finishes_at -> :ok end)

    PeertubeIndex.scan(["some-instance.example.com"], fn -> finishes_at end)

    Mox.verify!()
  end

  test "scan skips banned instances" do
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :find_instances, fn :banned -> ["banned-instance.example.com"] end)
    # We should not scan
    Mox.expect(PeertubeIndex.InstanceScanner.Mock, :scan, 0, fn instance -> {:error, :some_reason} end)

    PeertubeIndex.scan(["banned-instance.example.com"])

    Mox.verify!()
  end

  test "rescan" do
    {:ok, current_time} = NaiveDateTime.new(2018, 2, 2, 14, 15, 16)
    {:ok, maximum_date} = NaiveDateTime.new(2018, 2, 1, 14, 15, 16)

    discovered_instances = ["discovered1.example.com", "discovered2.example.com"]
    ok_and_old_enough_instances = ["ok1.example.com", "ok2.example.com"]
    failed_and_old_enough_instances = ["failed1.example.com", "failed2.example.com"]

    Mox.expect(PeertubeIndex.StatusStorage.Mock, :find_instances, fn :discovered -> discovered_instances end)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :find_instances, fn :ok, ^maximum_date -> ok_and_old_enough_instances end)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :find_instances, fn :error, ^maximum_date -> failed_and_old_enough_instances end)

    PeertubeIndex.rescan(fn -> current_time end, fn instances -> send self(), {:scan_function_called, instances} end)
    insances_to_rescan = discovered_instances ++ ok_and_old_enough_instances ++ failed_and_old_enough_instances

    Mox.verify!()
    assert_received {:scan_function_called, ^insances_to_rescan}
  end

  test "banning an instance removes all videos for this instance and saves its banned status" do
    {:ok, current_time} = NaiveDateTime.new(2019, 3, 1, 13, 14, 15)

    Mox.expect(PeertubeIndex.VideoStorage.Mock, :delete_instance_videos!, fn "instance-to-ban.example.com" -> :ok end)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :banned_instance, fn "instance-to-ban.example.com", "Provides illegal content", ^current_time -> :ok end)

    PeertubeIndex.ban_instance("instance-to-ban.example.com", "Provides illegal content", fn -> current_time end)

    Mox.verify!()
  end

  test "scan does not override an existing status with the discovered status" do
    # Given we have some instances with a status
    instances_with_a_status = ["known-instance-1.example.com",  "known-instance-2.example.com"]

    # When we discover those instances during a scan
    Mox.expect(
      PeertubeIndex.InstanceScanner.Mock, :scan,
      fn "some-instance.example.com" -> {:ok, {[], MapSet.new(instances_with_a_status)}} end
    )

    Mox.stub(PeertubeIndex.StatusStorage.Mock, :find_instances, fn :banned -> [] end)
    Mox.stub(PeertubeIndex.VideoStorage.Mock, :delete_instance_videos!, fn hostname -> :ok end)
    Mox.stub(PeertubeIndex.VideoStorage.Mock, :update_instance!, fn hostname, videos -> :ok end)
    Mox.stub(PeertubeIndex.StatusStorage.Mock, :ok_instance, fn "some-instance.example.com", date -> :ok end)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :has_a_status, 2, fn hostname -> Enum.member?(instances_with_a_status, hostname) end)

    # Then We must not change the status of instances discovered instances
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :discovered_instance, 0, fn hostname, date -> :ok end)

    PeertubeIndex.scan(["some-instance.example.com"])

    Mox.verify!()
  end

  test "removing a ban on an instance changes its status to discovered" do
    {:ok, current_time} = NaiveDateTime.new(2019, 3, 3, 12, 13, 14)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :discovered_instance, fn "unbanned-instance.example.com", ^current_time -> :ok end)
    PeertubeIndex.remove_ban("unbanned-instance.example.com", fn -> current_time end)
    Mox.verify!()
  end
end
