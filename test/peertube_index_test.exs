defmodule PeertubeIndexTest do
  use ExUnit.Case, async: true

  def scan_mocks do
    Mox.stub(PeertubeIndex.InstanceScanner.Mock, :scan, fn _hostname -> {:ok, {[], MapSet.new()}} end)

    Mox.stub(PeertubeIndex.VideoStorage.Mock, :delete_instance_videos!, fn _hostname -> :ok end)
    Mox.stub(PeertubeIndex.VideoStorage.Mock, :insert_videos!, fn _videos -> :ok end)

    Mox.stub(PeertubeIndex.StatusStorage.Mock, :find_instances, fn _status -> [] end)
    Mox.stub(PeertubeIndex.StatusStorage.Mock, :ok_instance, fn _hostname, _datetime -> :ok end)
    Mox.stub(PeertubeIndex.StatusStorage.Mock, :discovered_instance, fn _hostname, _datetime -> :ok end)
    Mox.stub(PeertubeIndex.StatusStorage.Mock, :failed_instance, fn _hostname, _reason, _datetime -> :ok end)
    Mox.stub(PeertubeIndex.StatusStorage.Mock, :has_a_status, fn _hostname -> false end)
  end

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

  test "scan uses instance scanner, deletes existing instance videos and inserts new ones in video storage" do
    scan_mocks()
    videos = [%{"name" => "some video"}]
    Mox.expect(PeertubeIndex.InstanceScanner.Mock, :scan, fn "some-instance.example.com" -> {:ok, {videos, MapSet.new()}} end)
    Mox.expect(PeertubeIndex.VideoStorage.Mock, :delete_instance_videos!, fn "some-instance.example.com" -> :ok end)
    Mox.expect(PeertubeIndex.VideoStorage.Mock, :insert_videos!, fn ^videos -> :ok end)

    videos = [%{"name" => "some other video"}]
    Mox.expect(PeertubeIndex.InstanceScanner.Mock, :scan, fn "some-other-instance.example.com" -> {:ok, {videos, MapSet.new()}} end)
    Mox.expect(PeertubeIndex.VideoStorage.Mock, :delete_instance_videos!, fn "some-other-instance.example.com" -> :ok end)
    Mox.expect(PeertubeIndex.VideoStorage.Mock, :insert_videos!, fn ^videos -> :ok end)

    PeertubeIndex.scan(["some-instance.example.com", "some-other-instance.example.com"])

    Mox.verify!()
  end

  test "scan updates instance status" do
    scan_mocks()
    {:ok, finishes_at} = NaiveDateTime.new(2018, 1, 1, 14, 15, 16)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :ok_instance, fn "some-instance.example.com", ^finishes_at -> :ok end)

    PeertubeIndex.scan(["some-instance.example.com"], fn -> finishes_at end)

    Mox.verify!()
  end

  test "scan reports the appropriate status for discovered instances" do
    scan_mocks()
    Mox.stub(
      PeertubeIndex.InstanceScanner.Mock, :scan,
      fn "some-instance.example.com" ->
        {:ok, {[], MapSet.new(["found-instance.example.com", "another-found-instance.example.com"])}}
      end
    )
    {:ok, finishes_at} = NaiveDateTime.new(2018, 1, 1, 14, 15, 16)
    # Then we set the status for the discovered instances
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :discovered_instance, fn "another-found-instance.example.com", ^finishes_at -> :ok end)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :discovered_instance, fn "found-instance.example.com", ^finishes_at -> :ok end)

    PeertubeIndex.scan(["some-instance.example.com"], fn -> finishes_at end)

    Mox.verify!()
  end

  test "scan does not override an existing status with the discovered status" do
    scan_mocks()
    # Given we have some instances with a status
    instances_with_a_status = ["known-instance-1.example.com",  "known-instance-2.example.com"]
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :has_a_status, 2, fn hostname -> Enum.member?(instances_with_a_status, hostname) end)

    # When we discover those instances during a scan
    Mox.expect(
      PeertubeIndex.InstanceScanner.Mock, :scan,
      fn "some-instance.example.com" -> {:ok, {[], MapSet.new(instances_with_a_status)}} end
    )

    # Then We must not change the status of instances discovered instances
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :discovered_instance, 0, fn _hostname, _date -> :ok end)

    PeertubeIndex.scan(["some-instance.example.com"])
    Mox.verify!()
  end

  test "scan handles failures, reports the corresponding statuses and deletes existing videos for the failed instance" do
    scan_mocks()
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
    Mox.expect(PeertubeIndex.InstanceScanner.Mock, :scan, 0, fn _instance -> nil end)

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

  test "removing a ban on an instance changes its status to discovered" do
    {:ok, current_time} = NaiveDateTime.new(2019, 3, 3, 12, 13, 14)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :discovered_instance, fn "unbanned-instance.example.com", ^current_time -> :ok end)
    PeertubeIndex.remove_ban("unbanned-instance.example.com", fn -> current_time end)
    Mox.verify!()
  end

  test "add_instances adds not yet known instances with the discovered status" do
    {:ok, current_time} = NaiveDateTime.new(2019, 5, 1, 17, 41, 55)

    # Given We do no know the instances
    Mox.stub(PeertubeIndex.StatusStorage.Mock, :has_a_status, fn _hostname -> false end)

    # Then We set the status for the discovered instances
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :discovered_instance, fn "an-instance.example.com", ^current_time -> :ok end)
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :discovered_instance, fn "another-instance.example.com", ^current_time -> :ok end)

    # When We add the instances
    PeertubeIndex.add_instances(["an-instance.example.com", "another-instance.example.com"], fn -> current_time end)

    Mox.verify!()
  end

  test "add_instances does not override an existing status" do
    {:ok, current_time} = NaiveDateTime.new(2019, 5, 1, 17, 48, 55)

    # Given We already have a status for an instance
    Mox.stub(PeertubeIndex.StatusStorage.Mock, :has_a_status, fn "already-known-instance.example.com" -> true end)

    # Then We do not change the status of the existing instance
    Mox.expect(PeertubeIndex.StatusStorage.Mock, :discovered_instance, 0, fn _hostname, _date -> :ok end)

    # When We try to add the instance
    PeertubeIndex.add_instances(["already-known-instance.example.com"], fn -> current_time end)

    Mox.verify!()
  end
end
