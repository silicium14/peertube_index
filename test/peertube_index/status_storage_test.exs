defmodule PeertubeIndex.StatusStorageTest do
  use ExUnit.Case, async: true

  @moduletag :integration

  test "status reporting functions create entries when instances have no status yet" do
    PeertubeIndex.StatusStorage.Filesystem.empty()

    PeertubeIndex.StatusStorage.Filesystem.ok_instance("example.com", ~N[2018-01-02 15:50:00])
    PeertubeIndex.StatusStorage.Filesystem.failed_instance("other.example.com", {:some_error_reason, "arbitrary error data"}, ~N[2018-01-03 16:20:00])
    PeertubeIndex.StatusStorage.Filesystem.discovered_instance("newly-discovered.example.com", ~N[2018-02-05 10:00:00])
    PeertubeIndex.StatusStorage.Filesystem.banned_instance("banned-instance.example.com", "Reason for the ban", ~N[2019-03-03 19:04:00])

    assert MapSet.new(PeertubeIndex.StatusStorage.Filesystem.all()) == MapSet.new([
             {"example.com", :ok, ~N[2018-01-02 15:50:00]},
             {"other.example.com", {:error, inspect({:some_error_reason, "arbitrary error data"})}, ~N[2018-01-03 16:20:00]},
             {"newly-discovered.example.com", :discovered, ~N[2018-02-05 10:00:00]},
             {"banned-instance.example.com", {:banned, "Reason for the ban"}, ~N[2019-03-03 19:04:00]}
           ])
  end

  # TODO: maybe this is business logic that should be implemented in a use case
  test "discover instance does not override an existing status except banned" do
    :ok = PeertubeIndex.StatusStorage.Filesystem.with_statuses([
      {"example.com", :ok, ~N[2018-03-11 20:10:31]},
      {"failed.example.com", {:error, :some_reason}, ~N[2018-03-12 09:01:22]},
      {"discovered.example.com", :discovered, ~N[2018-03-13 11:55:14]},
      {"banned-at-some-point.example.com", {:banned, "Some reason for a ban"}, ~N[2018-03-14 12:41:33]}
    ])

    PeertubeIndex.StatusStorage.Filesystem.discovered_instance("example.com", ~N[2018-03-11 20:10:32])
    PeertubeIndex.StatusStorage.Filesystem.discovered_instance("failed.example.com", ~N[2018-03-12 09:01:23])
    PeertubeIndex.StatusStorage.Filesystem.discovered_instance("discovered.example.com", ~N[2018-03-13 11:55:15])
    PeertubeIndex.StatusStorage.Filesystem.discovered_instance("banned-at-some-point.example.com", ~N[2018-04-01 09:00:00])

    assert MapSet.new(PeertubeIndex.StatusStorage.Filesystem.all()) == MapSet.new([
             {"example.com", :ok, ~N[2018-03-11 20:10:31]},
             {"failed.example.com", {:error, ":some_reason"}, ~N[2018-03-12 09:01:22]},
             {"discovered.example.com", :discovered, ~N[2018-03-13 11:55:14]},
             {"banned-at-some-point.example.com", :discovered, ~N[2018-04-01 09:00:00]},
           ])
  end

  test "find_instances with status" do
    :ok = PeertubeIndex.StatusStorage.Filesystem.with_statuses([
      {"discovered1.example.com", :discovered, ~N[2018-03-11 20:10:31]},
      {"discovered2.example.com", :discovered, ~N[2018-03-12 21:10:31]},
      {"ok1.example.com", :ok, ~N[2018-03-11 20:10:31]},
      {"ok2.example.com", :ok, ~N[2018-03-12 21:10:31]},
      {"failed1.example.com", {:error, :some_reason}, ~N[2018-03-11 20:10:31]},
      {"failed2.example.com", {:error, :some_reason}, ~N[2018-03-12 21:10:31]},
      {"banned1.example.com", {:banned, "Some reason for a ban"}, ~N[2018-03-13 20:10:31]},
      {"banned2.example.com", {:banned, "Some reason for a ban"}, ~N[2018-03-14 21:10:31]}
    ])

    instances = PeertubeIndex.StatusStorage.Filesystem.find_instances(:ok)
    assert MapSet.new(instances) == MapSet.new(["ok1.example.com", "ok2.example.com"])

    instances = PeertubeIndex.StatusStorage.Filesystem.find_instances(:discovered)
    assert MapSet.new(instances) == MapSet.new(["discovered1.example.com", "discovered2.example.com"])

    instances = PeertubeIndex.StatusStorage.Filesystem.find_instances(:error)
    assert MapSet.new(instances) == MapSet.new(["failed1.example.com", "failed2.example.com"])

    instances = PeertubeIndex.StatusStorage.Filesystem.find_instances(:banned)
    assert MapSet.new(instances) == MapSet.new(["banned1.example.com", "banned2.example.com"])
  end

  test "find_instances with status and maximum date" do
    year = 2018
    month = 3
    day = 10
    hour = 12
    minute = 30
    second = 30
    {:ok, maximum_date} = NaiveDateTime.new(year, month, day, hour, minute, second)
    {:ok, old_enough} = NaiveDateTime.new(year, month, day , hour, minute, second - 1)
    PeertubeIndex.StatusStorage.Filesystem.with_statuses([
      {"ok-too-recent.example.com", :ok, maximum_date},
      {"ok-old-enough.example.com", :ok, old_enough},
      {"failed-too-recent.example.com", {:error, :some_reason}, maximum_date},
      {"failed-old-enough.example.com", {:error, :some_reason}, old_enough},
      {"discovered-too-recent.example.com", :discovered, maximum_date},
      {"discovered-old-enough.example.com", :discovered, old_enough},
    ])

    instances = PeertubeIndex.StatusStorage.Filesystem.find_instances(:discovered, maximum_date)
    assert MapSet.new(instances) == MapSet.new(["discovered-old-enough.example.com"])

    instances = PeertubeIndex.StatusStorage.Filesystem.find_instances(:ok, maximum_date)
    assert MapSet.new(instances) == MapSet.new(["ok-old-enough.example.com"])

    instances = PeertubeIndex.StatusStorage.Filesystem.find_instances(:error, maximum_date)
    assert MapSet.new(instances) == MapSet.new(["failed-old-enough.example.com"])
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
