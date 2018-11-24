defmodule PeertubeIndex.VideoStorage do
  @moduledoc false

  @callback update_instance!(String.t, [map]) :: :ok
  @callback search(String.t) :: [map]

end
