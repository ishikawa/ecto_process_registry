defmodule EctoNameRegistry.Repo.Migrations.CreateRegistryNames do
  use Ecto.Migration

  @table "ecto_name_registry_names"

  def change do
    create table(@table) do
      add :name, :string, null: false
      timestamps updated_at: false
    end

    create unique_index(@table, [:name])
  end
end
