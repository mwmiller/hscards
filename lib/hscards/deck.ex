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
    proper = normalize(deck)
    included = Enum.reduce(deck.maindeck, MapSet.new(), fn c, a -> MapSet.put(a, c["dbfId"]) end)

    count_config = count_constraints(included)
    size_config = size_constraints(included)

    errors =
      %{}
      |> validate_counts(proper.maindeck, count_config)
      |> validate_counts(Map.get(proper, :sideboard, []), count_config)
      |> validate_size(proper, size_config)
      |> validate_zodiac(proper)

    case map_size(errors) do
      0 -> {:valid, proper}
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

  defp validate_size(acc, deck, {size, why}) do
    case size(deck) do
      %{maindeck: ^size} ->
        acc

      sizing ->
        Map.merge(acc, %{improper_size: sizing, size_constraint: why})
    end
  end

  defp size_constraints(included) do
    # These are only different versionof Renathal at present but I am
    # Making it flexible for later
    {dsc, dsms} =
      HSCards.DB.find(%{text: "deck_size", collectible: true})
      |> then(fn {:ambiguous, cards} -> cards end)
      |> Enum.reduce({%{}, MapSet.new()}, fn c, {m, s} ->
        dbf = c["dbfId"]
        {Map.put(m, dbf, c), MapSet.put(s, dbf)}
      end)

    case MapSet.intersection(dsms, included) |> MapSet.to_list() do
      [] ->
        {30, []}

      [adjust] ->
        card = dsc[adjust]

        # This probably needs more consideration later
        case Regex.named_captures(~r/(?<count>\d+)/, card["text"]) do
          %{"count" => c} -> {String.to_integer(c), card}
          _ -> {30, card}
        end
    end
  end

  defp validate_counts(acc, cards, config)

  defp validate_counts(acc, [], _), do: acc

  defp validate_counts(acc, [%{"count" => 1, "rarity" => "LEGENDARY"} | rest], config),
    do: validate_counts(acc, rest, config)

  defp validate_counts(acc, [%{"count" => c, "rarity" => r} | rest], {max_count, _} = config)
       when r != "LEGENDARY" and c <= max_count do
    validate_counts(acc, rest, config)
  end

  defp validate_counts(acc, [card | rest], {_, constraint} = config) do
    acc
    |> Map.put(:count_constraint, constraint)
    |> Map.update(:improper_count, [card], fn a -> [card | a] end)
    |> validate_counts(rest, config)
  end

  defp count_constraints(included) do
    {hlc, hlms} =
      HSCards.DB.find(%{text: "no duplicates", collectible: true})
      |> then(fn {:ambiguous, cards} -> cards end)
      |> Enum.reduce({%{}, MapSet.new()}, fn c, {m, s} ->
        dbf = c["dbfId"]
        {Map.put(m, dbf, c), MapSet.put(s, dbf)}
      end)

    case MapSet.intersection(hlms, included) |> MapSet.to_list() do
      [] -> {2, []}
      list -> {1, Enum.map(list, fn id -> hlc[id] end)}
    end
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
  defp combine([]), do: []

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
