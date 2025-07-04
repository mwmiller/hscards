defmodule TestData do
  # Test strings cribbed from the Hearthsim python tests
  # https://github.com/HearthSim/python-hearthstone/blob/master/tests/test_deckstrings.py
  # Except fever_dream which is mine
  @deckstrings %{
    pre_side_code: "AAEBAR8G+LEChwTmwgKhwgLZwgK7BQzquwKJwwKOwwKTwwK5tAK1A/4MqALsuwLrB86uAu0JAA==",
    regular: "AAEBAR8GhwS7BfixAqHCAtnCAubCAgyoArUD6wftCf4Mzq4CubQC6rsC7LsCicMCjsMCk8MCAAA=",
    sideboard:
      "AAEBAZCaBgjlsASotgSX7wTvkQXipAX9xAXPxgXGxwUQvp8EobYElrcE+dsEuNwEutwE9v" <>
        "AEhoMFopkF4KQFlMQFu8QFu8cFuJ4Gz54G0Z4GAAED8J8E/cQFuNkE/cQF/+EE/cQFAAA=",
    fever_dream:
      "AAEBAafDAyj+DeCsAoO7ApbEAonNAqDOAqniAvLsAqH+ApaKA4KUA86iA4ixA46xA8i+A/bdA5jeA/jjA4f3A4yBBOiLBIWjBKG2BLrtBP7uBJfvBKWRBZOSBfiWBbiYBZTEBc/2Bbj+Ba//BZueBr6hBq+oBsewBsK2BtOvBwAAAA==",
    raptor:
      "AAECAaIHCoukBb2+BrnBBvTJBpfXBvbdBqLhBszhBqrqBsODBwr2nwT3nwS2tQaGvwbpyQaW1gaL3Aae3Aaa5gbk6gYAAA==",
    pegasus:
      "AAECAZ8FBNK5BtG/BrrOBpfXBg3JoASS1AS1ngbTngbCvgbBvwbDvwbKvwbtyQbzyQaM1gaW1gaA1wYAAA=="
  }

  def strings, do: Map.values(@deckstrings)
  def string(which), do: Map.get(@deckstrings, which, %{})

  @decks %{
    abnormal: %{
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
    },
    normal: %{
      maindeck: [
        %{"cost" => 1, "count" => 2, "dbfId" => 1, "name" => "one"},
        %{"cost" => 2, "count" => 1, "dbfId" => 2, "name" => "two"}
      ],
      sideboard: [%{"cost" => 4, "count" => 1, "dbfId" => 4, "name" => "four", "owner" => 2}],
      heroes: [%{"cost" => 0, "count" => 1, "dbfId" => 0, "name" => "Zero"}]
    }
  }

  def deck(which), do: Map.get(@decks, which, %{})
end
