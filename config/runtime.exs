import Config

config :hscards, HSCards.Repo, database: "/tmp/hscards.db", load_extensions: [SqliteVec.path()]
