defmodule EctoNameRegistry.Repo.Migrations.AddNodeInRegistryPids do
  use Ecto.Migration

  def change do
    alter table("ecto_name_registry_pids") do
      add :node, :string, null: false
    end
  end
end
