defmodule HSCards.Deck do
  @moduledoc """
  Functions for dealing with deck maps
  """

  alias HSCards.Constraints

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

    vres =
      deck
      |> gather_deck_info
      |> Constraints.verify()

    case vres do
      :valid -> {:valid, proper}
      other -> other
    end
  end

  defp gather_deck_info(%{heroes: heroes} = deck) do
    keys = Constraints.keys()
    # Heroes has a special case, so we need to handle it separately
    do_deck_info(deck.maindeck, keys, %{"heroes" => heroes})
  end

  defp do_deck_info([], _keys, info), do: info

  defp do_deck_info([card | rest], keys, info) do
    ni = Enum.reduce(keys, info, fn k, a -> second_level_update(a, k, card[k], card["dbfId"]) end)
    do_deck_info(rest, keys, ni)
  end

  # Kernel.update_in/3 is more general, but doesn't do what I want exactly
  defp second_level_update(map, _, nil, _), do: map

  defp second_level_update(map, fk, sk, val) when is_list(sk) do
    Enum.reduce(sk, map, fn ssk, a -> second_level_update(a, fk, ssk, val) end)
  end

  defp second_level_update(map, fk, sk, val) do
    Map.update(map, fk, %{sk => MapSet.new([val])}, fn inside ->
      Map.update(inside, sk, MapSet.new([val]), fn p -> MapSet.put(p, val) end)
    end)
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
