{:ok, _} = EctoProcessRegistry.Repo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(EctoProcessRegistry.Repo, :manual)
ExUnit.start()
