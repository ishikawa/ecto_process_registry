defmodule EctoNameRegistry.Pid do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key false
  schema "ecto_name_registry_pids" do
    field :key, :string, primary_key: true
    belongs_to :name, EctoNameRegistry.Name, primary_key: true
    field :node, :binary
    field :pid, :binary
    timestamps updated_at: false
  end

  @spec create_changeset(Ecto.Schema.t() | Ecto.Changeset.t(), map) :: Ecto.Changeset.t()
  def create_changeset(data, params) do
    data
    |> cast(params, [:key, :pid, :node])
    |> unique_constraint(:key, name: :ecto_name_registry_pids_pkey)
  end
end
