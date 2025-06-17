defmodule HSCard do
  use Ecto.Schema

  schema "cards" do
    field(:dbfId, :integer)
    field(:name, :string)
    field(:full_info, :map)
  end
end
