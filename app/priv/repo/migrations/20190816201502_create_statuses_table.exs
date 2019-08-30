defmodule PeertubeIndex.StatusStorage.Repo.Migrations.CreateStatusesTable do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE status AS ENUM ('ok', 'error', 'discovered', 'banned')",
      "DROP TYPE status"
    )
    # TODO `:string` type should be postgres type `text` and not `character varying(255)`
    create table(:statuses, primary_key: false) do
      add :host, :text, primary_key: true
      add :status, :status, null: false
      add :reason, :text
      add :date, :naive_datetime, null: false, default: fragment("now()")
    end
  end
end
