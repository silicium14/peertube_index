defmodule PeertubeIndex.InstanceAPI do
  @moduledoc false

  @callback scan(String.t, integer) :: {[map], MapSet.t}
  # With a default argument
  @callback scan(String.t) :: {[map], MapSet.t}

end
