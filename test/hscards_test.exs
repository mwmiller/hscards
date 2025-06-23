defmodule HSCardsTest do
  use ExUnit.Case, async: true
  doctest HSCards

  test "deckstrings round trip" do
    # Tests cribbed from the Hearthsim python tests
    # https://github.com/HearthSim/python-hearthstone/blob/master/tests/test_deckstrings.py

    pre_side_code = "AAEBAR8G+LEChwTmwgKhwgLZwgK7BQzquwKJwwKOwwKTwwK5tAK1A/4MqALsuwLrB86uAu0JAA=="

    assert pre_side_code ==
             pre_side_code |> HSCards.from_deckstring() |> HSCards.to_deckstring()

    regular = "AAEBAR8GhwS7BfixAqHCAtnCAubCAgyoArUD6wftCf4Mzq4CubQC6rsC7LsCicMCjsMCk8MCAAA="

    assert regular ==
             regular |> HSCards.from_deckstring() |> HSCards.to_deckstring()

    sideboard =
      "AAEBAZCaBgjlsASotgSX7wTvkQXipAX9xAXPxgXGxwUQvp8EobYElrcE+dsEuNwEutwE9v" <>
        "AEhoMFopkF4KQFlMQFu8QFu8cFuJ4Gz54G0Z4GAAED8J8E/cQFuNkE/cQF/+EE/cQFAAA="

    assert sideboard ==
             sideboard |> HSCards.from_deckstring() |> HSCards.to_deckstring()

    # My own deck as she is played.
    fever_dream =
      "AAEBAafDAyj+DeCsAoO7ApbEAonNAqDOAqniAvLsAqH+ApaKA4KUA86iA4ixA46xA8i+A/bdA5jeA/jjA4f3A4yBBOiLBIWjBKG2BLrtBP7uBJfvBKWRBZOSBfiWBbiYBZTEBc/2Bbj+Ba//BZueBr6hBq+oBsewBsK2BtOvBwAAAA=="

    assert fever_dream ==
             fever_dream |> HSCards.from_deckstring() |> HSCards.to_deckstring()
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
