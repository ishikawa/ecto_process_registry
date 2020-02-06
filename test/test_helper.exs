{:ok, _} = EctoNameRegistry.Repo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(EctoNameRegistry.Repo, :manual)
ExUnit.start()
