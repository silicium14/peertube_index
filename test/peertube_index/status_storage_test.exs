defmodule PeertubeIndex.StatusStorageTest do
  use ExUnit.Case, async: true

  @moduletag :integration
  @status_storage PeertubeIndex.StatusStorage.Postgresql

  setup do
    @status_storage.empty()
    PeertubeIndex.StatusStorage.Repo.start_link()
    :ok
  end

  test "status reporting functions create entries when instances have no status yet" do
    @status_storage.ok_instance("example.com", ~N[2018-01-02 15:50:00])
    @status_storage.failed_instance("other.example.com", {:some_error_reason, "arbitrary error data"}, ~N[2018-01-03 16:20:00])
    @status_storage.discovered_instance("newly-discovered.example.com", ~N[2018-02-05 10:00:00])
    @status_storage.banned_instance("banned-instance.example.com", "Reason for the ban", ~N[2019-03-03 19:04:00])

    assert MapSet.new(@status_storage.all()) == MapSet.new([
             {"example.com", :ok, ~N[2018-01-02 15:50:00]},
             {"other.example.com", {:error, inspect({:some_error_reason, "arbitrary error data"})}, ~N[2018-01-03 16:20:00]},
             {"newly-discovered.example.com", :discovered, ~N[2018-02-05 10:00:00]},
             {"banned-instance.example.com", {:banned, "Reason for the ban"}, ~N[2019-03-03 19:04:00]}
           ])
  end

  test "find_instances with status" do
    :ok = @status_storage.with_statuses([
      {"discovered1.example.com", :discovered, ~N[2018-03-11 20:10:31]},
      {"discovered2.example.com", :discovered, ~N[2018-03-12 21:10:31]},
      {"ok1.example.com", :ok, ~N[2018-03-11 20:10:31]},
      {"ok2.example.com", :ok, ~N[2018-03-12 21:10:31]},
      {"failed1.example.com", {:error, :some_reason}, ~N[2018-03-11 20:10:31]},
      {"failed2.example.com", {:error, :some_reason}, ~N[2018-03-12 21:10:31]},
      {"banned1.example.com", {:banned, "Some reason for a ban"}, ~N[2018-03-13 20:10:31]},
      {"banned2.example.com", {:banned, "Some reason for a ban"}, ~N[2018-03-14 21:10:31]}
    ])

    instances = @status_storage.find_instances(:ok)
    assert MapSet.new(instances) == MapSet.new(["ok1.example.com", "ok2.example.com"])

    instances = @status_storage.find_instances(:discovered)
    assert MapSet.new(instances) == MapSet.new(["discovered1.example.com", "discovered2.example.com"])

    instances = @status_storage.find_instances(:error)
    assert MapSet.new(instances) == MapSet.new(["failed1.example.com", "failed2.example.com"])

    instances = @status_storage.find_instances(:banned)
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
    @status_storage.with_statuses([
      {"ok-too-recent.example.com", :ok, maximum_date},
      {"ok-old-enough.example.com", :ok, old_enough},
      {"failed-too-recent.example.com", {:error, :some_reason}, maximum_date},
      {"failed-old-enough.example.com", {:error, :some_reason}, old_enough},
      {"discovered-too-recent.example.com", :discovered, maximum_date},
      {"discovered-old-enough.example.com", :discovered, old_enough},
    ])

    instances = @status_storage.find_instances(:discovered, maximum_date)
    assert MapSet.new(instances) == MapSet.new(["discovered-old-enough.example.com"])

    instances = @status_storage.find_instances(:ok, maximum_date)
    assert MapSet.new(instances) == MapSet.new(["ok-old-enough.example.com"])

    instances = @status_storage.find_instances(:error, maximum_date)
    assert MapSet.new(instances) == MapSet.new(["failed-old-enough.example.com"])
  end

  test "failed_instance overrides existing status" do
    :ok = @status_storage.with_statuses([{"example.com", :ok, ~N[2018-03-11 20:10:31]}])
    assert @status_storage.failed_instance("example.com", {:some_error_reason, "arbitrary error data"}, ~N[2018-04-01 12:40:00]) == :ok
    assert @status_storage.all() == [{"example.com", {:error, inspect({:some_error_reason, "arbitrary error data"})}, ~N[2018-04-01 12:40:00]}]
  end

  test "ok_instance overrides existing status" do
    :ok = @status_storage.with_statuses([{"example.com", :ok, ~N[2018-03-11 20:10:31]}])
    assert @status_storage.ok_instance("example.com", ~N[2018-04-01 12:40:00]) == :ok
    assert @status_storage.all() == [{"example.com", :ok, ~N[2018-04-01 12:40:00]}]
  end

  test "discovered_instance overrides existing status" do
    :ok = @status_storage.with_statuses([{"example.com", :ok, ~N[2019-03-03 21:23:44]}])
    assert @status_storage.discovered_instance("example.com", ~N[2019-03-04 04:05:29]) == :ok
    assert @status_storage.all() == [{"example.com", :discovered, ~N[2019-03-04 04:05:29]}]
  end

  test "banned_instance overrides existing status" do
    :ok = @status_storage.with_statuses([{"example.com", :ok, ~N[2019-03-03 21:23:44]}])
    assert @status_storage.banned_instance("example.com", "Reason for the ban", ~N[2019-03-04 04:05:29]) == :ok
    assert @status_storage.all() == [{"example.com", {:banned, "Reason for the ban"}, ~N[2019-03-04 04:05:29]}]
  end

  test "can insert arbitrary strings" do
    @status_storage.failed_instance("example.com", "A string with 'single quotes'", ~N[2019-08-23 17:16:33])
    @status_storage.banned_instance("2.example.com", "A string with 'single quotes'", ~N[2019-08-23 17:16:33])
    assert MapSet.new(@status_storage.all()) == MapSet.new([
      {"example.com", {:error, inspect("A string with 'single quotes'")}, ~N[2019-08-23 17:16:33]},
      {"2.example.com", {:banned, "A string with 'single quotes'"}, ~N[2019-08-23 17:16:33]},
    ])
  end

  test "has_a_status" do
    known_instance = "known-instance.example.com"
    :ok = @status_storage.with_statuses([{known_instance, :ok, ~N[2018-03-11 20:10:31]}])
    assert @status_storage.has_a_status(known_instance) == true
    assert @status_storage.has_a_status("unknown-instance.example.com") == false
  end
end
