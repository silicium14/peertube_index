defmodule PeertubeIndex.VideoStorageTest do
  use ExUnit.Case, async: true

  @moduletag :integration


  test "we can search videos" do
    videos = [%{"name" => "A cat video", "nsfw" => false}, %{"name" => "A video about a cat", "nsfw" => false}]
    PeertubeIndex.VideoStorage.Elasticsearch.with_videos(videos)
    Process.sleep 1_000
    assert MapSet.new(PeertubeIndex.VideoStorage.Elasticsearch.search("cat")) == MapSet.new(videos)
  end

  test "search excludes NSFW videos by default" do
    safe_video = %{"name" => "A video", "nsfw" => false}
    videos = [safe_video, %{"name" => "Another video", "nsfw" => true}]
    PeertubeIndex.VideoStorage.Elasticsearch.with_videos(videos)
    Process.sleep 1_000
    assert PeertubeIndex.VideoStorage.Elasticsearch.search("video") == [safe_video]
  end

  test "update_instance! adds videos and we can search them" do
    # Given I have an empty index
    PeertubeIndex.VideoStorage.Elasticsearch.empty()
    # When I update an instance with some videos
    a_video = %{"name" => "A dummy video", "nsfw" => false}
    another_video = %{"name" => "An interesting video", "nsfw" => false}
    PeertubeIndex.VideoStorage.Elasticsearch.update_instance!("example.com", [a_video, another_video])
    Process.sleep 1_000
    # Then
    assert PeertubeIndex.VideoStorage.Elasticsearch.search("dummy") == [a_video]
    assert PeertubeIndex.VideoStorage.Elasticsearch.search("interesting") == [another_video]
  end

  test "update_instance! deletes existing instance videos" do
    # Given We have videos from two instances
    other_instance_video = %{"name" => "Other instance video", "account" => %{"host" => "other.example.com"}, "nsfw" => false}
    video = %{"name" => "A dummy video", "account" => %{"host" => "example.com"}, "nsfw" => false}
    PeertubeIndex.VideoStorage.Elasticsearch.with_videos([video, other_instance_video])
    Process.sleep 1_000
    # When I update instance with no videos
    PeertubeIndex.VideoStorage.Elasticsearch.update_instance!("example.com", [])
    Process.sleep 1_000
    # Then
    assert PeertubeIndex.VideoStorage.Elasticsearch.search("dummy") == []
    assert PeertubeIndex.VideoStorage.Elasticsearch.search("other instance") == [other_instance_video]
  end
end
