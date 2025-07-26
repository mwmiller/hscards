defmodule HSCards.Art do
  use Ecto.Schema

  schema "art" do
    field(:hs_id, :string)
    field(:tile, :string)
    field(:full, :string)
  end
end
