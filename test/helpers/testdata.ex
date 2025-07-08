defmodule TestData do
  # Test strings cribbed from the Hearthsim python tests
  # https://github.com/HearthSim/python-hearthstone/blob/master/tests/test_deckstrings.py
  # Except fever_dream which is mine
  @deckstrings %{
    valid: %{
      pre_side_code:
        "AAEBAR8G+LEChwTmwgKhwgLZwgK7BQzquwKJwwKOwwKTwwK5tAK1A/4MqALsuwLrB86uAu0JAA==",
      regular: "AAEBAR8GhwS7BfixAqHCAtnCAubCAgyoArUD6wftCf4Mzq4CubQC6rsC7LsCicMCjsMCk8MCAAA=",
      sideboard:
        "AAEBAZCaBgjlsASotgSX7wTvkQXipAX9xAXPxgXGxwUQvp8EobYElrcE+dsEuNwEutwE9v" <>
          "AEhoMFopkF4KQFlMQFu8QFu8cFuJ4Gz54G0Z4GAAED8J8E/cQFuNkE/cQF/+EE/cQFAAA=",
      fever_dream:
        "AAEBAafDAyj+DeCsAoO7ApbEAonNAqDOAqniAvLsAqH+ApaKA4KUA86iA4ixA46xA8i+A/bdA5jeA/jjA4f3A4yBBOiLBIWjBKG2BLrtBP7uBJfvBKWRBZOSBfiWBbiYBZTEBc/2Bbj+Ba//BZueBr6hBq+oBsewBsK2BtOvBwAAAA==",
      raptor:
        "AAECAaIHCoukBb2+BrnBBvTJBpfXBvbdBqLhBszhBqrqBsODBwr2nwT3nwS2tQaGvwbpyQaW1gaL3Aae3Aaa5gbk6gYAAA==",
      pegasus:
        "AAECAZ8FBNK5BtG/BrrOBpfXBg3JoASS1AS1ngbTngbCvgbBvwbDvwbKvwbtyQbzyQaM1gaW1gaA1wYAAA==",
      no_minion:
        "AAECAf0EArqnBpKDBw79ngTboQWxoAblpgbmpgazpwbluAbFugaBvwaxzgbL0AaF5gaG5gbxkQcAAA==",
      racist_paladin:
        "AAEBAZ8FCtwDyLgD/LgDhMEDk9ADv9EDwNEDw9ED4NEDiN4DCpuuA5yuA8q4A/24A+q5A+u5A+y5A8rBA57NA8rRAwAA",
      esho_hunter: "AAECAR8CmKAEwrEHDqmfBOD4BcufBuelBuqlBvGlBvKlBv+lBsyWB96WB+CWB+KWB9CbB/anBwAA"
    },
    invalid: %{
      princes:
        "AAEBAZ8FKN0KghDLrAKgtwKLvQK4xwKc4gKd4gKe4gLQ9ALA/QLZ/gL5kwP9pQOezQOPzgPM6wO09gP09gOV+QPxpATlsATQvQS/4gSX7wSnkwX9xAWO9QW5/gWFjgbBnwbLnwbqqQabuAbBvwbOvwaW0wbO5Qbt5gar6gYAAAA=",
      baku_hunter:
        "AAEBAR8IjQHP8gKe+AKFsAP9+AOIsgTbuQSX7wQQqAKAB/gH6asCgtAD2+0D9/gDqZ8Eqp8EwawEnbAEhLIEhMkEwNMEwdMEidQEAAA=",
      even_warrior:
        "AAEBAQcGzfQCwLkD/cQFpfYF+skGquoGDM/nAri5A/mMBPqMBO/OBI7UBJD7BaH7BYuUBpyeBp+eBtW6BgABA/qwA/3EBaPvBP3EBdGeBv3EBQAA",
      elise_the_nav:
        "AAECAaa0BgqAoATHpAaopQbR5Qbt6gailgfslgeCmAf0qgeKsQcKy58GpKcG0dAGltMGltYG+OIGx4cHnZYH5pYH0ZsHAAEC9rMGx6QG97MGx6QGAAA="
    }
  }

  def strings(:all), do: strings(:valid) ++ strings(:invalid)
  def strings(class), do: Map.values(@deckstrings[class])

  def string(which) do
    case get_in(@deckstrings, [:valid, which]) do
      nil -> get_in(@deckstrings, [:invalid, which])
      val -> val
    end
  end

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
