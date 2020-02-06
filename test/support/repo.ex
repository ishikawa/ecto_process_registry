defmodule EctoNameRegistry.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :ecto_name_registry,
    adapter: Ecto.Adapters.Postgres
end
