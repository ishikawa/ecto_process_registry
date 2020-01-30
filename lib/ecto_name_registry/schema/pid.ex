defmodule EctoNameRegistry.Pid do
  use Ecto.Schema

  @primary_key false
  schema "ecto_name_registry_pids" do
    field :pid, :binary, primary_key: true
    field :key, :string, primary_key: true

    belongs_to :name, EctoNameRegistry.Name
    timestamps updated_at: false
  end
end
