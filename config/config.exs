import Config

config :logger, :console, level: :warning

config :hscards,
  ecto_repos: [HSCards.Repo]

import_config "#{config_env()}.exs"
