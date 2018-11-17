defmodule PeertubeIndex.StorageTest do
  use ExUnit.Case

  @moduletag :integration


  test "we can search videos" do
    video = %{"name" => "A dummy video"}
    PeertubeIndex.Storage._with_videos([video])
    Process.sleep 1_000
    assert PeertubeIndex.Storage.search("dummy") == [video]
  end

  test "update_instance adds videos and we can search them" do
    # Given I have an empty index
    PeertubeIndex.Storage._empty()
    # When I update an instance with some videos
    a_video = %{"name" => "A dummy video"}
    another_video = %{"name" => "An interesting video"}
    PeertubeIndex.Storage.update_instance("example.com", [a_video, another_video])
    Process.sleep 1_000
    # Then
    assert PeertubeIndex.Storage.search("dummy") == [a_video]
    assert PeertubeIndex.Storage.search("interesting") == [another_video]
  end

  test "update_instance deletes existing instance videos" do
    # Given We have videos from two instances
    other_instance_video = %{"name" => "Other instance video", "account" => %{"host" => "other.example.com"}}
    video = %{"name" => "A dummy video", "account" => %{"host" => "example.com"}}
    PeertubeIndex.Storage._with_videos([video, other_instance_video])
    Process.sleep 1_000
    # When I update instance with no videos
    PeertubeIndex.Storage.update_instance("example.com", [])
    Process.sleep 1_000
    # Then
    assert PeertubeIndex.Storage.search("dummy") == []
    assert PeertubeIndex.Storage.search("other instance") == [other_instance_video]
  end
end
