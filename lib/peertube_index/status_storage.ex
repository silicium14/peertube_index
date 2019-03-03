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
  Notify a failed instance scan, with a reason, at the given datetime
  """
  @callback failed_instance(String.t, any(), NaiveDateTime.t) :: :ok

  @doc """
  Notify a discovered instance at the given datetime.
  This will not override any previously existing status for the same instance.
  """
  @callback discovered_instance(String.t, NaiveDateTime.t) :: :ok

  @doc """
  Notify a banned instance, with a reason, at the given datetime
  """
  @callback banned_instance(String.t, String.t, NaiveDateTime.t) :: :ok
end

defmodule PeertubeIndex.StatusStorage.Filesystem do
  @moduledoc false

  @behaviour PeertubeIndex.StatusStorage
  def directory, do: Confex.fetch_env!(:peertube_index, :status_storage_directory)

  @impl true
  def empty do
    File.rm_rf(directory())
    File.mkdir!(directory())
  end

  @impl true
  def with_statuses(statuses) do
    empty()
    for status <- statuses do
      case status do
        {host, :ok, date} ->
          write_status_map(host, %{"host" => host, "status" => "ok", "date" => date})
        {host, {:error, reason}, date} ->
          write_status_map(host, %{"host" => host, "status" => "error", "reason" => inspect(reason), "date" => date})
        {host, :discovered, date} ->
          write_status_map(host, %{"host" => host, "status" => "discovered", "date" => date})
        {host, {:banned, reason}, date} ->
          write_status_map(host, %{"host" => host, "status" => "banned", "reason" => reason, "date" => date})
      end
    end

    :ok
  end

  @impl true
  def all do
    for file <- File.ls!(directory()) do
      {:ok, bytes} = :file.read_file("#{directory()}/#{file}")
      status_map = Poison.decode!(bytes)
      case status_map do
        %{"host" => host, "status" => "discovered", "date" => date_string} ->
          {host, :discovered, NaiveDateTime.from_iso8601!(date_string)}
        %{"host" => host, "status" => "ok", "date" => date_string} ->
          {host, :ok, NaiveDateTime.from_iso8601!(date_string)}
        %{"host" => host, "status" => "error", "reason" => reason_string, "date" => date_string} ->
          {host, {:error, reason_string}, NaiveDateTime.from_iso8601!(date_string)}
        %{"host" => host, "status" => "banned", "reason" => reason_string, "date" => date_string} ->
          {host, {:banned, reason_string}, NaiveDateTime.from_iso8601!(date_string)}
      end
    end
  end

  @impl true
  def find_instances(wanted_status) do
    all()
    |> Enum.filter(&matches_status?(&1, wanted_status))
    |> Enum.map(fn {host, _status, _date} -> host end)
    |> Enum.to_list()
  end

  @impl true
  def find_instances(wanted_status, maximum_date) do
    all()
    |> Enum.filter(&matches_status?(&1, wanted_status))
    |> Enum.filter(fn {_host, _status, date} -> NaiveDateTime.compare(date, maximum_date) == :lt end)
    |> Enum.map(fn {host, _status, _date} -> host end)
    |> Enum.to_list()
  end

  defp matches_status?({_host, instance_status, _date}, wanted_status) do
    case instance_status do
      {^wanted_status, _reason} ->
        true
      ^wanted_status ->
        true
      _ ->
        false
    end
  end

  @impl true
  def ok_instance(host, date) do
    write_status_map(host, %{"host" => host, "status" => "ok", "date" => date})
  end

  @impl true
  def failed_instance(host, reason, date) do
    write_status_map(host, %{"host" => host, "status" => "error", "reason" => inspect(reason), "date" => date})
  end

  @impl true
  def discovered_instance(host, date) do
    if has_no_already_existing_status_except_banned(host) do
      write_status_map(host, %{"host" => host, "status" => "discovered", "date" => date})
    end
  end

  @impl true
  def banned_instance(host, reason, date) do
    write_status_map(host, %{"host" => host, "status" => "banned", "reason" => reason, "date" => date})
  end

  defp write_status_map(host, status_map) do
    {:ok, file} = :file.open(host_file(host), [:raw, :write])
    :file.write(file, Poison.encode!(status_map, pretty: true))
    :file.close(file)
  end

  # TODO: this is ugly, change it
  defp has_no_already_existing_status_except_banned(host) do
    (
      host
      |> host_file()
      |> File.exists?()
      |> Kernel.not()
    ) or (
      {:ok, bytes} = host |> host_file() |> :file.read_file()
      status_map = Poison.decode!(bytes)
      case status_map do
        %{"status" => "banned"} ->
          true
        _ ->
          false
      end
    )
  end

  defp host_file(host) do
    "#{directory()}/#{host}.json"
  end
end
