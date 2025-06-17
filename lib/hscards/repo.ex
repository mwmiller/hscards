defmodule HSCards.Repo do
  use Ecto.Repo, otp_app: :hscards, adapter: Ecto.Adapters.SQLite3
end
