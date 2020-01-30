defmodule EctoNameRegistry.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {EctoNameRegistry.Repo, []}
    ]

    opts = [strategy: :one_for_one, name: EctoNameRegistry.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
