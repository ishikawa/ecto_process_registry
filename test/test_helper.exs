{:ok, _} = EctoProcessRegistry.Repo.start_link()

:ok = LocalCluster.start()

Application.ensure_all_started(:ecto_process_registry)

Ecto.Adapters.SQL.Sandbox.mode(EctoProcessRegistry.Repo, :manual)

ExUnit.start()
