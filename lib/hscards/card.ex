defmodule HSCards.Card do
  use Ecto.Schema

  schema "cards" do
    field(:dbfId, :integer)
    field(:name, :string)
    field(:artist, :string)
    field(:flavor, :string)
    field(:full_info, :map)
    field(:class, :string)
    field(:mechanic, :string)
    field(:cost, :integer)
  end
end
