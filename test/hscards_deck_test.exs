defmodule HSCardsDeckTest do
  use ExUnit.Case, async: true
  doctest HSCards.Deck
  alias HSCards.Deck

  @abnormal %{
    heroes: [%{"dbfId" => 0, "name" => "Zero", "cost" => 0, "count" => 1}],
    maindeck: [
      %{"dbfId" => 1, "name" => "one", "cost" => 1, "count" => 1},
      %{"dbfId" => 2, "name" => "two", "cost" => 2, "count" => 1},
      %{"dbfId" => 1, "name" => "one", "cost" => 1, "count" => 1}
    ],
    sideboard: [
      %{"dbfId" => 3, "name" => "three", "cost" => 3, "count" => 1},
      %{"dbfId" => 4, "name" => "four", "cost" => 4, "count" => 1, "owner" => 2},
      %{"dbfId" => 5, "name" => "five", "cost" => 5, "count" => 1, "owner" => 0},
      %{"dbfId" => 6, "name" => "six", "cost" => 6, "count" => 2, "owner" => 2}
    ]
  }

  @normal %{
    maindeck: [
      %{"cost" => 1, "count" => 2, "dbfId" => 1, "name" => "one"},
      %{"cost" => 2, "count" => 1, "dbfId" => 2, "name" => "two"}
    ],
    sideboard: [%{"cost" => 4, "count" => 1, "dbfId" => 4, "name" => "four", "owner" => 2}],
    heroes: [%{"cost" => 0, "count" => 1, "dbfId" => 0, "name" => "Zero"}]
  }

  test "normalize and size" do
    assert @normal == Deck.normalize(@abnormal)
    assert %{heroes: 1, maindeck: 3, sideboard: 5} = Deck.size(@abnormal)
    assert %{heroes: 1, maindeck: 3, sideboard: 1} = Deck.size(@normal)
  end
end
