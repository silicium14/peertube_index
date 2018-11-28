defmodule PeertubeIndex.VideoStorage do
  @moduledoc false

  @doc """
  Updates an instance with a list of videos.
  This removes existing videos for the given instance and inserts the given videos.
  """
  @callback update_instance!(String.t, [map]) :: :ok

  @doc """
  Search for a video by its name
  """
  @callback search(String.t) :: [map]

  @doc """
  Create a video storage with some videos for testing
  """
  @callback with_videos([map]) :: :ok

  @doc """
  Create an empty video storage for testing
  """
  @callback empty() :: :ok

end
