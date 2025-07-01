defmodule HSCardsTest do
  use ExUnit.Case, async: true
  doctest HSCards

  test "deckstrings round trip" do
    Enum.each(TestData.strings(), fn s ->
      assert s == s |> HSCards.from_deckstring() |> HSCards.to_deckstring()
    end)
  end

  test "rune cost strings" do
    assert "tri-blood" == HSCards.rune_cost_string(%{"blood" => 3, "frost" => 0, "unholy" => 0})
    assert "tri-frost" == HSCards.rune_cost_string(%{"blood" => 0, "frost" => 3})
    assert "tri-unholy" == HSCards.rune_cost_string(%{"unholy" => 3})
    assert "BB" == HSCards.rune_cost_string(%{"blood" => 2})
    assert "F" == HSCards.rune_cost_string(%{"frost" => 1})
    assert "UUF" == HSCards.rune_cost_string(%{"unholy" => 2, "frost" => 1})
    assert "rainbow" == HSCards.rune_cost_string(%{"blood" => 1, "frost" => 1, "unholy" => 1})
    assert "invalid" == HSCards.rune_cost_string(%{"blood" => 1, "frost" => 1, "unholy" => 2})
  end

  test "by_name" do
    assert {:ok, %{"name" => "Keymaster Alabaster"}} = HSCards.by_name("Alabaster")

    assert {:ambiguous, cards} = HSCards.by_name("benedictus")
    assert length(cards) == 4

    assert {:error, _} = HSCards.by_name("Nonexistent Card")
  end

  test "by_artist" do
    heavy_hitter = "Alex Horley Orlandelli"
    # Very unlikely to get a single artist hit with fuzzy search
    assert {:ambiguous, cards} = HSCards.by_artist(heavy_hitter)
    # Credit shouldn't disappear we hope
    assert length(cards) > 300
    assert Enum.all?(cards, fn card -> card["artist"] == heavy_hitter end)

    assert {:error, _} = HSCards.by_artist("Pablo Picasso")
  end

  test "by_flavor" do
    assert {:ok, %{"dbfId" => 38227}} = HSCards.by_flavor("Nobody expects the Vilefin")
    assert {:ambiguous, spanish} = HSCards.by_flavor("Nobody expects the ")
    # Should not drop we hope!
    assert length(spanish) > 2
    # We're done when this fails
    assert {:error, _} = HSCards.by_flavor("skibidi")
  end
end
