defmodule AnomaExplorer.Repo.Migrations.AddAppSettings do
  use Ecto.Migration

  def change do
    create table(:app_settings) do
      add :key, :string, null: false
      add :value, :text
      add :description, :string

      timestamps()
    end

    create unique_index(:app_settings, [:key])
  end
end
