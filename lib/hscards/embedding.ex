defmodule HSCards.Embedding do
  use Ecto.Schema

  schema "embeddings" do
    field(:dbfId, :integer)
    field(:embedding, SqliteVec.Ecto.Float32)
  end
end
