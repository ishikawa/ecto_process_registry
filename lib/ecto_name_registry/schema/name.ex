defmodule EctoNameRegistry.Name do
  use Ecto.Schema

  schema "ecto_name_registry_names" do
    field :name, :string
    timestamps updated_at: false
  end
end
