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
  @callback all() :: [tuple()]

  @doc """
  Find instances that have the given status and with a status updated before the given date
  """
  @callback find_instances(:ok | :error | :discovered, NaiveDateTime.t) :: [String.t]

  @doc """
  Find instances that have the given status
  """
  @callback find_instances(:ok | :error | :discovered) :: [String.t]


  @doc """
  Notify a successful instance scan at the given datetime
  """
  @callback ok_instance(String.t, NaiveDateTime.t) :: :ok

  @doc """
  Notify a failed instance scan at the given datetime
  """
  @callback failed_instance(String.t, any(), NaiveDateTime.t) :: :ok

  @doc """
  Notify a discovered instance at the given datetime.
  This will not override any previously existing status for the same instance.
  """
  @callback discovered_instance(String.t, NaiveDateTime.t) :: :ok
end
