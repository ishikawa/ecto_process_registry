import Config

config :logger, level: :warn

config :ecto_name_registry, ecto_repos: [EctoNameRegistry.Repo]

config :ecto_name_registry, EctoNameRegistry.Repo,
  database: "ecto_name_registry_repo_test",
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
