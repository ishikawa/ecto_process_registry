import Config

config :logger, level: :warn

config :ecto_process_registry, ecto_repos: [EctoProcessRegistry.Repo]

config :ecto_process_registry, EctoProcessRegistry.Repo,
  database: "ecto_process_registry_repo_test",
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
