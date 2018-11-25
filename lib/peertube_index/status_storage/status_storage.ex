defmodule PeertubeIndex.StatusStorage do
  @moduledoc false


  @doc """
  Create an empty status storage for testing
  """
  @callback empty() :: :ok

  @doc """
  Returns the list of all statuses
  """
  @callback all() :: :ok
  @callback new_status(String.t, :ok | {:error, any()}, NaiveDateTime.t) :: :ok
  @callback instances_to_rescan((-> NaiveDateTime.t)) :: list(String.t)

end
