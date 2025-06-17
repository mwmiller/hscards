import Config

config :logger, :console, level: :warning

config :hscards,
  ecto_repos: [HSCards.Repo]

config :hscards, HSCards.Repo, database: "priv/repo/hscards.db"
