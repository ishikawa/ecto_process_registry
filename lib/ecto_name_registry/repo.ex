defmodule EctoNameRegistry.Repo do
  use Ecto.Repo,
    otp_app: :ecto_name_registry,
    # NOTE: Can we support other adapters?
    adapter: Ecto.Adapters.Postgres
end
