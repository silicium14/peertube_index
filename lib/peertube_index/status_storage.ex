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

  @doc """
  Returns true if a instance (identified by it's hostname) has a status in the database,
  and false otherwise
  """
  @callback has_a_status(String.t) :: boolean()
end

defmodule PeertubeIndex.StatusStorage.Postgresql do
  @moduledoc false

  @behaviour PeertubeIndex.StatusStorage

  @impl true
  def empty do
    Mix.Tasks.Ecto.Drop.run([])
    Mix.Tasks.Ecto.Create.run([])
    Mix.Tasks.Ecto.Migrate.run([])
    :ok
  end

  @impl true
  def with_statuses(statuses) do
    for status <- statuses do
      case status do
        {host, :ok, date} ->
          Ecto.Adapters.SQL.query(
            PeertubeIndex.StatusStorage.Repo,
            "INSERT INTO statuses (host, status, date) VALUES ('#{host}', 'ok', '#{NaiveDateTime.to_iso8601(date)}')"
          )
        {host, {:error, reason}, date} ->
          Ecto.Adapters.SQL.query(
            PeertubeIndex.StatusStorage.Repo,
            "INSERT INTO statuses (host, status, reason, date) VALUES ('#{host}', 'error', '#{inspect(reason)}', '#{NaiveDateTime.to_iso8601(date)}')"
          )
        {host, :discovered, date} ->
          Ecto.Adapters.SQL.query(
            PeertubeIndex.StatusStorage.Repo,
            "INSERT INTO statuses (host, status, date) VALUES ('#{host}', 'discovered', '#{NaiveDateTime.to_iso8601(date)}')"
          )
        {host, {:banned, reason}, date} ->
          Ecto.Adapters.SQL.query(
            PeertubeIndex.StatusStorage.Repo,
            "INSERT INTO statuses (host, status, reason, date) VALUES ('#{host}', 'banned', '#{reason}', '#{NaiveDateTime.to_iso8601(date)}')"
          )
      end
    end
    :ok
  end

  @impl true
  def all do
    {:ok, result} = Ecto.Adapters.SQL.query PeertubeIndex.StatusStorage.Repo, "select host, status, reason, date from statuses"
    for row <- result.rows do
      case List.to_tuple(row) do
        {host, "discovered", nil, date} ->
          {host, :discovered, date |> NaiveDateTime.truncate(:second)}
        {host, "ok", nil, date} ->
          {host, :ok, date |> NaiveDateTime.truncate(:second)}
        {host, "error", reason_string, date} ->
          {host, {:error, reason_string}, date |> NaiveDateTime.truncate(:second)}
        {host, "banned", reason_string, date} ->
          {host, {:banned, reason_string}, date |> NaiveDateTime.truncate(:second)}
      end
    end
  end

  @impl true
  def find_instances(wanted_status, maximum_date) do
    {:ok, r} = Ecto.Adapters.SQL.query(
      PeertubeIndex.StatusStorage.Repo,
      "
      SELECT host
      FROM statuses
      WHERE status = '#{wanted_status}'
      AND date < '#{NaiveDateTime.to_iso8601(maximum_date)}'
      "
    )
    r.rows
    |> Enum.map(&Enum.at(&1, 0))
  end

  @impl true
  def find_instances(wanted_status) do
    {:ok, r} = Ecto.Adapters.SQL.query(
      PeertubeIndex.StatusStorage.Repo,
      "SELECT host FROM statuses WHERE status = '#{wanted_status}'"
    )
    r.rows
    |> Enum.map(&Enum.at(&1, 0))
  end

  @impl true
  def ok_instance(host, date) do
    {:ok, _} = Ecto.Adapters.SQL.query(
      PeertubeIndex.StatusStorage.Repo,
      "
      INSERT INTO statuses (host, status, date)
      VALUES ($1, 'ok', $2)
      ON CONFLICT (host)
      DO UPDATE SET status = EXCLUDED.status, date = EXCLUDED.date
      ",
      [host, date]
    )
    :ok
  end

  @impl true
  def failed_instance(host, reason, date) do
    {:ok, _} = Ecto.Adapters.SQL.query(
      PeertubeIndex.StatusStorage.Repo,
      "
      INSERT INTO statuses (host, status, reason, date)
      VALUES ($1, 'error', $2, $3)
      ON CONFLICT (host)
      DO UPDATE SET status = EXCLUDED.status, reason = EXCLUDED.reason, date = EXCLUDED.date
      ",
      [host, inspect(reason), date]
    )
    :ok
  end

  @impl true
  def discovered_instance(host, date) do
   {:ok, _} = Ecto.Adapters.SQL.query(
      PeertubeIndex.StatusStorage.Repo,
      "
      INSERT INTO statuses (host, status, reason, date)
      VALUES ($1, 'discovered', null, $2)
      ON CONFLICT (host)
      DO UPDATE SET status = EXCLUDED.status, reason = EXCLUDED.reason, date = EXCLUDED.date
      ",
      [host, date]
    )
    :ok
  end

  @impl true
  def banned_instance(host, reason, date) do
    {:ok, _} = Ecto.Adapters.SQL.query(
      PeertubeIndex.StatusStorage.Repo,
      "
      INSERT INTO statuses (host, status, reason, date)
      VALUES ($1, 'banned', $2, $3)
      ON CONFLICT (host)
      DO UPDATE SET status = EXCLUDED.status, reason = EXCLUDED.reason, date = EXCLUDED.date
      ",
      [host, reason, date]
    )
    :ok
  end

  @impl true
  def has_a_status(host) do
    {:ok, r} = Ecto.Adapters.SQL.query(
      PeertubeIndex.StatusStorage.Repo,
      "SELECT count(*) FROM statuses WHERE host = '#{host}'"
    )
    count = r.rows |> Enum.at(0) |> Enum.at(0)
    count == 1
  end
end

defmodule PeertubeIndex.StatusStorage.Repo do
  use Ecto.Repo,
    otp_app: :peertube_index,
    adapter: Ecto.Adapters.Postgres

  def init(_, config) do
    url = Confex.fetch_env!(:peertube_index, :status_storage_database_url)
    {:ok, Keyword.put(config, :url, url)}
  end
end
