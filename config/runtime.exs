import Config

config :hscards, HSCards.Repo, database: "priv/db/hscards.db", load_extensions: [SqliteVec.path()]
