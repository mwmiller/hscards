# HSCards

Functions to deal wiith Hearthstone cards.

The SQLite database can be configured from inside your config.ex file.

```
config :hscards,
  ecto_repos: [HSCards.Repo]

config :hscards, HSCards.Repo, database: "priv/db/hscards.db"
```

After that, you can create and run the migrations:

```
mix ecto.create
mix ecto.migrate
```

You can then use the functions in the `HSCards` module to interact with the database.
Loading the cards from the database can be done with:

```elixir
HSCards.sync_to_latest_db()
```

