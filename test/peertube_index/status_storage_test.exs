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

  test "discover instance does not override an existing status" do
    :ok = PeertubeIndex.StatusStorage.Filesystem.with_statuses([
      {"example.com", :ok, ~N[2018-03-11 20:10:31]},
      {"failed.example.com", {:error, :some_reason}, ~N[2018-03-12 09:01:22]},
      {"discovered.example.com", :discovered, ~N[2018-03-13 11:55:14]},
    ])

    PeertubeIndex.StatusStorage.Filesystem.discovered_instance("example.com", ~N[2018-03-11 20:10:32])
    PeertubeIndex.StatusStorage.Filesystem.discovered_instance("failed.example.com", ~N[2018-03-12 09:01:23])
    PeertubeIndex.StatusStorage.Filesystem.discovered_instance("discovered.example.com", ~N[2018-03-13 11:55:15])

    assert MapSet.new(PeertubeIndex.StatusStorage.Filesystem.all()) == MapSet.new([
             {"example.com", :ok, ~N[2018-03-11 20:10:31]},
             {"failed.example.com", {:error, ":some_reason"}, ~N[2018-03-12 09:01:22]},
             {"discovered.example.com", :discovered, ~N[2018-03-13 11:55:14]},
           ])
  end

  test "instances to rescan are the discovered instances and failed or ok instances with a status older than a day" do
    year = 2018
    month = 3
    day = 10
    hour = 12
    minute = 30
    second = 30

    {:ok, very_recent} = NaiveDateTime.new(year, month, day, hour, minute, second - 1)
    {:ok, just_more_that_a_day_ago} = NaiveDateTime.new(year, month, day - 1, hour, minute, second - 1)
    PeertubeIndex.StatusStorage.Filesystem.with_statuses([
      {"ok-too-recent.example.com", :ok, very_recent},
      {"ok-old-enough.example.com", :ok, just_more_that_a_day_ago},
      {"failed-too-recent.example.com", {:error, :some_reason}, very_recent},
      {"failed-old-enough.example.com", {:error, :some_reason}, just_more_that_a_day_ago},
      {"discovered.example.com", :discovered, very_recent},
    ])

    {:ok, current_time} = NaiveDateTime.new(year, month, day, hour, minute, second)
    instances_to_rescan = PeertubeIndex.StatusStorage.Filesystem.instances_to_rescan(fn -> current_time end)
    assert MapSet.new(instances_to_rescan) == MapSet.new(["ok-old-enough.example.com", "failed-old-enough.example.com", "discovered.example.com"])
  end

  test "failed_instance overrides existing status" do
    :ok = PeertubeIndex.StatusStorage.Filesystem.with_statuses([{"example.com", :ok, ~N[2018-03-11 20:10:31]}])

    PeertubeIndex.StatusStorage.Filesystem.failed_instance("example.com", {:some_error_reason, "arbitrary error data"}, ~N[2018-04-01 12:40:00])

    assert PeertubeIndex.StatusStorage.Filesystem.all() == [{"example.com", {:error, inspect({:some_error_reason, "arbitrary error data"})}, ~N[2018-04-01 12:40:00]}]
  end

  test "ok_instance overrides existing status" do
    :ok = PeertubeIndex.StatusStorage.Filesystem.with_statuses([{"example.com", :ok, ~N[2018-03-11 20:10:31]}])

    PeertubeIndex.StatusStorage.Filesystem.ok_instance("example.com", ~N[2018-04-01 12:40:00])

    assert PeertubeIndex.StatusStorage.Filesystem.all() == [{"example.com", :ok, ~N[2018-04-01 12:40:00]}]
  end
end
