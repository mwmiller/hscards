defmodule HSCardSetsTest do
  use ExUnit.Case, async: true
  doctest HSCards.Sets
  alias HSCards.Sets

  test "some deckstrings from around" do
    assert {:ok, "Year of the Raptor"} =
             Sets.zodiac_from_deck(
               "AAECAaIHCoukBb2+BrnBBvTJBpfXBvbdBqLhBszhBqrqBsODBwr2nwT3nwS2tQaGvwbpyQaW1gaL3Aae3Aaa5gbk6gYAAA=="
             )

    assert {:ok, "Year of the Pegasus"} =
             Sets.zodiac_from_deck(
               "AAECAZ8FBNK5BtG/BrrOBpfXBg3JoASS1AS1ngbTngbCvgbBvwbDvwbKvwbtyQbzyQaM1gaW1gaA1wYAAA=="
             )

    assert {:error, "Must supply a valid standard deck to determine year"} =
             Sets.zodiac_from_deck(
               "AAEBAZICDpvwAtn5A4mLBKWtBL/OBK/kBObkBZ/zBaOiBqD0Bqn1BrT3BqyIB4CuBwjhFa6fBNGcBoeoBoexBpb0Bsf4BqCBBwAA"
             )

    assert {:error, _deckstring_bad} = Sets.zodiac_from_deck("ABCDE")
  end
end
