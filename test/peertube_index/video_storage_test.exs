defmodule PeertubeIndex.VideoStorageTest do
  use ExUnit.Case, async: true

  @moduletag :integration

  test "we can search videos" do
    videos = [
      %{"name" => "A cat video"},
      %{"name" => "Another video about a cat"}
    ]
    PeertubeIndex.VideoStorage.Elasticsearch.with_videos(videos)
    Process.sleep 1_000
    assert MapSet.new(PeertubeIndex.VideoStorage.Elasticsearch.search("cat")) == MapSet.new(videos)
  end

  test "search is fuzzy" do
    videos = [%{"name" => "Cats best moments"}]
    PeertubeIndex.VideoStorage.Elasticsearch.with_videos(videos)
    Process.sleep 1_000
    assert MapSet.new(PeertubeIndex.VideoStorage.Elasticsearch.search("cat best momt")) == MapSet.new(videos)
  end

  test "search can filter on NSFW" do
    safe_video = %{"name" => "A safe video", "nsfw" => false}
    unsafe_video = %{"name" => "An unsafe video", "nsfw" => true}
    videos = [safe_video, unsafe_video]
    PeertubeIndex.VideoStorage.Elasticsearch.with_videos(videos)
    Process.sleep 1_000
    assert MapSet.new(PeertubeIndex.VideoStorage.Elasticsearch.search("video")) == MapSet.new([safe_video, unsafe_video])
    assert PeertubeIndex.VideoStorage.Elasticsearch.search("video", nsfw: false) == [safe_video]
    assert PeertubeIndex.VideoStorage.Elasticsearch.search("video", nsfw: true) == [unsafe_video]
  end

  test "search gives the first 100 results" do
    videos =
    for index <- 1..110 do
      %{"name" => "A cat video", "uuid" => "#{index}"}
    end
    PeertubeIndex.VideoStorage.Elasticsearch.with_videos(videos)
    Process.sleep 1_000
    assert length(PeertubeIndex.VideoStorage.Elasticsearch.search("video")) == 100
  end

  test "update_instance! adds videos and we can search them" do
    # Given I have an empty index
    PeertubeIndex.VideoStorage.Elasticsearch.empty()
    # When I update an instance with some videos
    a_video = %{"name" => "A dummy video"}
    another_video = %{"name" => "An interesting video"}
    PeertubeIndex.VideoStorage.Elasticsearch.update_instance!("example.com", [a_video, another_video])
    Process.sleep 1_000
    # Then
    assert PeertubeIndex.VideoStorage.Elasticsearch.search("dummy") == [a_video]
    assert PeertubeIndex.VideoStorage.Elasticsearch.search("interesting") == [another_video]
  end

  test "update_instance! deletes existing instance videos" do
    # Given We have videos from two instances
    video = %{"name" => "A dummy video", "account" => %{"host" => "example.com"}}
    other_instance_video = %{"name" => "Other instance video", "account" => %{"host" => "other.example.com"}}
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
