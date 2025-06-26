defmodule HSCards.Repo.Migrations.Embed do
  use Ecto.Migration

  def up do
    # Keep in sync with the creator
    execute(
      "CREATE TABLE embeddings(id INTEGER PRIMARY KEY, embedding float[512], dbfId INTEGER UNIQUE)"
    )
  end

  def down do
    execute("DROP TABLE embeddings")
  end
end
