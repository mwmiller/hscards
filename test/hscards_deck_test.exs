defmodule HSCardsDeckTest do
  use ExUnit.Case, async: true
  doctest HSCards.Deck
  alias HSCards.Deck

  test "normalize and size" do
    normal = TestData.deck(:normal)
    abnormal = TestData.deck(:abnormal)
    assert normal == Deck.normalize(abnormal)
    assert %{heroes: 1, maindeck: 3, sideboard: 5} = Deck.size(abnormal)
    assert %{heroes: 1, maindeck: 3, sideboard: 1} = Deck.size(normal)
  end

  test "validate" do
    Enum.each(TestData.strings(), fn d -> assert {:valid, _deck} = Deck.validate(d) end)
  end
end
