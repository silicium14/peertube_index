defmodule PeertubeIndex.InstanceAPI do
  @moduledoc false

  @callback scan(String.t, integer, boolean) :: {:ok, {[map], MapSet.t}} | {:error, any()}
  # With default arguments
  @callback scan(String.t) :: {:ok, {[map], MapSet.t}} | {:error, any()}

end
