defmodule HSCards.Deck do
  @moduledoc """
  Functions for dealing with deck maps
  """

  @card_keys [:heroes, :maindeck, :sideboard]

  @doc """
  Validate a deck
  """
  # This is focused on :wild and :standard
  def validate(deck) when is_binary(deck) do
    deck |> HSCards.from_deckstring() |> validate
  end

  def validate(deck) do
    errors =
      %{}
      |> validate_counts(deck.maindeck)
      |> validate_counts(Map.get(deck, :sideboard, []))
      |> validate_size(deck)
      |> validate_zodiac(deck)

    case map_size(errors) do
      0 -> {:valid, deck}
      1 -> {:invalid, errors}
    end
  end

  defp validate_zodiac(acc, %{format: :wild}), do: acc

  defp validate_zodiac(acc, deck) do
    # If we stuck in the zodiac key then we already did the check
    case Map.get(deck, :zodiac) do
      nil -> Map.put(acc, :non_standard_sets, deck.sets)
      _ -> acc
    end
  end

  defp validate_size(acc, deck) do
    md_size =
      case Enum.find(deck.maindeck, fn c -> c["dbfId"] == 79767 end) do
        nil -> 30
        _ -> 40
      end

    case size(deck) do
      %{maindeck: ^md_size} ->
        acc

      sizing ->
        Map.put(acc, :improper_size, sizing)
    end
  end

  defp validate_counts(acc, cards)

  defp validate_counts(acc, []), do: acc

  defp validate_counts(acc, [%{"count" => 1, "rarity" => "LEGENDARY"} | rest]),
    do: validate_counts(acc, rest)

  defp validate_counts(acc, [%{"count" => c, "rarity" => r} | rest])
       when r != "LEGENDARY" and c <= 2 do
    validate_counts(acc, rest)
  end

  defp validate_counts(acc, [card | rest]) do
    validate_counts(Map.update(acc, :improper_count, [card], fn a -> [card | a] end), rest)
  end

  @doc """
  Normalize a deck
  - Sort cards like display
  - Combine any duplicates
  - Remove unowned sideboard
  """
  def normalize(deck) do
    deck |> normalize(@card_keys) |> check_sideboard
  end

  defp normalize(deck, []), do: deck

  defp normalize(deck, [k | eys]) do
    case Map.get(deck, k) do
      nil ->
        normalize(deck, eys)

      list ->
        cards =
          list
          |> Enum.reject(fn c -> Map.get(c, "count", 0) < 1 end)
          |> Enum.sort_by(& &1["name"])
          |> Enum.sort_by(& &1["cost"])
          |> combine

        normalize(Map.put(deck, k, cards), eys)
    end
  end

  # Once they are sorted we can work out dupe protection
  defp combine([c | ards]) do
    combine(ards, [c])
  end

  # Put them back into sorted order
  defp combine([], stack), do: Enum.reverse(stack)

  defp combine([%{"dbfId" => ci, "count" => cc} | rest], [%{"dbfId" => ci} = prev | stack]) do
    # Looks like the previous card, combine their counts
    # and skip this one
    combine(rest, [Map.update(prev, "count", cc, fn pc -> pc + cc end) | stack])
  end

  defp combine([curr | rest], stack) do
    # Does not match, so shift it into the card stack
    combine(rest, [curr | stack])
  end

  defp check_sideboard(%{maindeck: mb, sideboard: sb} = deck) when length(sb) > 0 do
    owners =
      mb
      |> Enum.reduce([], fn
        %{"dbfId" => id, "count" => 1}, a -> [id | a]
        _, a -> a
      end)
      |> MapSet.new()

    nsb =
      sb
      |> Enum.reduce([], fn c, a ->
        case MapSet.member?(owners, c["owner"]) and c["count"] == 1 do
          true -> [c | a]
          false -> a
        end
      end)
      |> Enum.reverse()

    %{deck | sideboard: nsb}
  end

  defp check_sideboard(deck), do: deck

  def size(deck) do
    Enum.reduce(@card_keys, %{}, fn k, a -> Map.put(a, k, size_of(deck, k)) end)
  end

  defp size_of(deck, which) do
    deck |> Map.get(which, []) |> Enum.sum_by(fn c -> Map.get(c, "count", 0) end)
  end
end
