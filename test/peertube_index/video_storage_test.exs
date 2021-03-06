defmodule PeertubeIndex.VideoStorageTest do
  use ExUnit.Case, async: true

  @moduletag :integration

  test "we can search videos" do
    videos = [
      %{"name" => "A cat video"},
      %{"name" => "Another video about a cat"}
    ]
    PeertubeIndex.VideoStorage.Elasticsearch.with_videos!(videos)
    Process.sleep 1_000
    assert MapSet.new(PeertubeIndex.VideoStorage.Elasticsearch.search("cat")) == MapSet.new(videos)
  end

  test "search is fuzzy" do
    videos = [%{"name" => "Cats best moments"}]
    PeertubeIndex.VideoStorage.Elasticsearch.with_videos!(videos)
    Process.sleep 1_000
    assert MapSet.new(PeertubeIndex.VideoStorage.Elasticsearch.search("cat best momt")) == MapSet.new(videos)
  end

  test "search can filter on NSFW" do
    safe_video = %{"name" => "A safe video", "nsfw" => false}
    unsafe_video = %{"name" => "An unsafe video", "nsfw" => true}
    videos = [safe_video, unsafe_video]
    PeertubeIndex.VideoStorage.Elasticsearch.with_videos!(videos)
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
    PeertubeIndex.VideoStorage.Elasticsearch.with_videos!(videos)
    Process.sleep 1_000
    assert length(PeertubeIndex.VideoStorage.Elasticsearch.search("video")) == 100
  end

  test "insert_videos! adds videos and we can search them" do
    # Given I have an empty index
    PeertubeIndex.VideoStorage.Elasticsearch.empty!()
    # When I update an instance with some videos
    a_video = %{"name" => "A dummy video"}
    another_video = %{"name" => "An interesting video"}
    PeertubeIndex.VideoStorage.Elasticsearch.insert_videos!([a_video, another_video])
    Process.sleep 1_000
    # Then
    assert PeertubeIndex.VideoStorage.Elasticsearch.search("dummy") == [a_video]
    assert PeertubeIndex.VideoStorage.Elasticsearch.search("interesting") == [another_video]
  end

  test "delete_instance_videos! removes videos of the given instance" do
    # Given We have videos
    videos = [
      %{"name" => "A dummy video", "account" => %{"host" => "example.com"}},
      %{"name" => "Another dummy video", "account" => %{"host" => "example.com"}}
    ]
    PeertubeIndex.VideoStorage.Elasticsearch.with_videos!(videos)
    Process.sleep 1_000
    # When I delete videos of the instance
    PeertubeIndex.VideoStorage.Elasticsearch.delete_instance_videos!("example.com")
    Process.sleep 1_000
    # Then
    assert PeertubeIndex.VideoStorage.Elasticsearch.search("dummy") == []
  end
end
