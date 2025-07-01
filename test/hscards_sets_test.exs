defmodule HSCardSetsTest do
  use ExUnit.Case, async: true
  doctest HSCards.Sets
  alias HSCards.Sets

  test "some deckstrings from around" do
    assert %{zodiac: %{name: "Year of the Raptor"}} =
             :raptor |> TestData.string() |> Sets.add_deck_info()

    assert %{zodiac: %{name: "Year of the Pegasus"}} =
             :pegasus |> TestData.string() |> Sets.add_deck_info()

    # My crazy wild deck
    assert %{sets: many} = :fever_dream |> TestData.string() |> Sets.add_deck_info()
    assert length(many) > 20
  end
end
