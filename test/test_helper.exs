{:ok, _} = EctoProcessRegistry.Repo.start_link()

{_, 0} = System.cmd("epmd", ["-daemon"])
:ok = LocalCluster.start()

Application.ensure_all_started(:ecto_process_registry)

Ecto.Adapters.SQL.Sandbox.mode(EctoProcessRegistry.Repo, :manual)

ExUnit.start()
