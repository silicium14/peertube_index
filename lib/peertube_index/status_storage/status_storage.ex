defmodule PeertubeIndex.StatusStorage do
  @moduledoc false

  @callback new_status(String.t, :ok | {:error, any()}, Datetime.t) :: :ok
  @callback instances_to_rescan((-> Datetime.t)) :: list(String.t)

end
