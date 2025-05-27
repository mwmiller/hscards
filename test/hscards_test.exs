defmodule HSCardsTest do
  use ExUnit.Case
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
      "AAEBAafDAyj+DeCsAoO7ApbEAonNAqDOAvLsAtz1ApaKA4KUA86iA5ioA4ixA46xA8i+A/bdA5jeA/jjA4f3A4yBBOiLBIWjBKG2BLrtBP7uBJfvBKWRBZOSBfiWBbiYBZTEBc/2Bbj+Ba//BZueBq+oBsewBsK2Bq+IB9OvBwAAAA=="

    assert fever_dream ==
             fever_dream |> HSCards.from_deckstring() |> HSCards.to_deckstring()
  end
end
