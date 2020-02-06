defmodule EctoProcessRegistry.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :ecto_process_registry,
    adapter: Ecto.Adapters.Postgres
end
