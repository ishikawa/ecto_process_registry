defmodule EctoProcessRegistry.Repo.Migrations.CreateRegistryPids do
  use Ecto.Migration

  def change do
    create table("ecto_process_registry_pids", primary_key: false) do
      add :name_id, references("ecto_process_registry_names"), primary_key: true, null: false
      add :key, :string, primary_key: true, null: false
      add :node, :string, null: false
      add :pid, :binary, null: false
      timestamps updated_at: false
    end
  end
end
