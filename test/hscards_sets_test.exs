defmodule HSCardSetsTest do
  use ExUnit.Case, async: true
  doctest HSCards.Sets
  alias HSCards.Sets

  test "some deckstrings from around" do
    assert %{zodiac: %{name: "Year of the Raptor"}} =
             Sets.add_deck_info(
               "AAECAaIHCoukBb2+BrnBBvTJBpfXBvbdBqLhBszhBqrqBsODBwr2nwT3nwS2tQaGvwbpyQaW1gaL3Aae3Aaa5gbk6gYAAA=="
             )

    assert %{zodiac: %{name: "Year of the Pegasus"}} =
             Sets.add_deck_info(
               "AAECAZ8FBNK5BtG/BrrOBpfXBg3JoASS1AS1ngbTngbCvgbBvwbDvwbKvwbtyQbzyQaM1gaW1gaA1wYAAA=="
             )

    # My crazy wild deck
    assert %{sets: many} =
             Sets.add_deck_info(
               "AAEBAafDAyj+DeCsAoO7ApbEAonNAqDOAqniAvLsAqH+ApaKA4KUA86iA4ixA46xA8i+A/bdA5jeA/jjA4f3A4yBBOiLBIWjBKG2BLrtBP7uBJfvBKWRBZOSBfiWBbiYBZTEBc/2Bbj+Ba//BZueBr6hBq+oBsewBsK2BtOvBwAAAA=="
             )

    assert length(many) > 20
  end
end
