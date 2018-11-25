defmodule PeertubeIndex.StatusStorage do
  @moduledoc false


  @doc """
  Create an empty status storage for testing
  """
  @callback empty() :: :ok

  @doc """
  Create a status storage with given statuses for testing
  """
  @callback with_statuses([tuple()]) :: :ok

  @doc """
  Returns the list of all statuses
  """
  @callback all() :: :ok
  @callback ok_instance(String.t, NaiveDateTime.t) :: :ok
  @callback failed_instance(String.t, any(), NaiveDateTime.t) :: :ok
  @callback discovered_instance(String.t, NaiveDateTime.t) :: :ok

  @doc """
  Returns the instances that are just discovered and the ok or failed instances with a status older than a day
  """
  @callback instances_to_rescan((-> NaiveDateTime.t)) :: list(String.t)

end
