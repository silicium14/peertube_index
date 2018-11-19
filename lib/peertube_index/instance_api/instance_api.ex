defmodule PeertubeIndex.InstanceAPI do
  @moduledoc false

  @callback scan(String.t, integer) :: {:ok, {[map], MapSet.t}} | {:error, any()}
  # With a default argument
  @callback scan(String.t) :: {:ok, {[map], MapSet.t}} | {:error, any()}

end
