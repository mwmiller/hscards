defmodule HSCards.Constraints do
  @moduledoc """
  Deck building constraints reified
  """
  # String keys for less marshalling
  # This associates with the functions, we'll see if we can find a way to combine
  @constraints %{
    "ten different costs" => %{text_match: "10 cards of different Costs", constrained: ["cost"]},
    "least expensive minion" => %{
      text_match: "less than every minion",
      constrained: ["cost", "type"]
    },
    "most expensive minion" => %{
      text_match: "more than every minion",
      constrained: ["cost", "type"]
    },
    "no dupe" => %{text_match: "no duplicates", constrained: ["count"]},
    "no minion" => %{text_match: "deck has no minions", constrained: ["type"]},
    "no neutral" => %{text_match: "no Neutral cards", constrained: ["cardClass"]},
    "no two cost" => %{text_match: "no 2-Cost cards", constrained: ["cost"]},
    "no three cost" => %{text_match: "no 3-Cost cards", constrained: ["cost"]},
    "no four cost" => %{text_match: "no 4-Cost cards", constrained: ["cost"]},
    "all nature spells" => %{
      text_match: "each spell in your deck is Nature",
      constrained: ["type", "spellSchool"]
    },
    "all shadow spells" => %{
      text_match: "deck are all Shadow",
      constrained: ["type", "spellSchool"]
    },
    "only even" => %{text_match: "only even-Cost cards", constrained: ["cost"]},
    "only odd" => %{text_match: "only odd-Cost cards", constrained: ["cost"]},
    "all minions same type" => %{
      text_match: "deck shares a minion type",
      constrained: ["races", "type"]
    },
    "deck size forty" => %{
      text_match: "Your deck size and starting Health are 40.",
      constrained: ["count"]
    },
    "base rules" => %{constrained: ["runeCost", "count", "rarity"]},
    "none" => %{constrained: ["constraint"]}
  }
  @keys @constraints
        |> Enum.reduce(MapSet.new(), fn {_, %{constrained: c}}, a ->
          Enum.reduce(c, a, fn e, acc -> MapSet.put(acc, e) end)
        end)
        |> MapSet.to_list()

  @doc """
  List all known constraint types
  """

  def known, do: Map.keys(@constraints)

  @doc """
  List all keys constrained by known types
  """
  def keys, do: @keys

  @doc """
  Emit constraint for given card text
  """
  def for_card_text(card_text)

  def for_card_text(t) when is_binary(t) do
    # Should only be one
    case Enum.find(@constraints, fn
           {_, %{text_match: tm}} -> String.contains?(t, tm)
           _ -> false
         end) do
      nil -> "none"
      {constraint, _meta} -> constraint
    end
  end

  def for_card_text(_), do: :none

  def verify(deck_info)

  # Always apply these last so we can drop ones which are not needed
  @base_checks [{"deck size thirty", []}, {"rarity count", []}, {"rune cost", []}]

  def verify(%{"constraint" => cons} = di) do
    # It's important to do the base checks last, so we can drop them if not needed
    constraint_list = cons |> Enum.to_list() |> then(fn c -> c ++ @base_checks end)

    case verify_constraints(constraint_list, di) do
      [] -> :valid
      broken -> {:invalid, broken}
    end
  end

  def verify(_) do
    :valid
  end

  defp verify_constraints(constraints, deck_info, acc \\ [])
  defp verify_constraints([], _di, acc), do: acc

  defp verify_constraints([{"none", _} | rest], di, acc),
    do: verify_constraints(rest, di, acc)

  defp verify_constraints([{"deck size forty", from} | rest], %{"count" => c} = di, acc) do
    na =
      case Enum.reduce(c, 0, fn {count, cards}, a -> a + count * length(cards) end) do
        40 ->
          acc

        n ->
          [constraint_invalid("deck size forty", from, "Deck size of #{n}") | acc]
      end

    verify_constraints(rest -- [{"deck size thirty", []}], di, na)
  end

  defp verify_constraints([{"deck size thirty", from} | rest], %{"count" => c} = di, acc) do
    na =
      case Enum.reduce(c, 0, fn {count, cards}, a -> a + count * length(cards) end) do
        30 ->
          acc

        n ->
          [constraint_invalid("deck size thirty", from, "Deck size of #{n}") | acc]
      end

    verify_constraints(rest -- [{"deck size thirty", []}], di, na)
  end

  defp verify_constraints([{"no dupe", from} | rest], %{"count" => c} = di, acc) do
    na =
      case Enum.filter(c, fn {k, _v} -> k != 1 end) do
        [] ->
          acc

        broken ->
          [constraint_invalid("no dupe", from, broken) | acc]
      end

    verify_constraints(rest -- [{"rarity count", []}], di, na)
  end

  defp verify_constraints(
         [{"rarity count", from} | rest],
         %{"rarity" => r, "count" => c} = di,
         acc
       ) do
    l = MapSet.new(r["LEGENDARY"] || [])

    o =
      r
      |> Enum.reduce(MapSet.new(), fn
        {"LEGENDARY", _}, a -> a
        {_, v}, a -> v |> MapSet.new() |> MapSet.union(a)
      end)

    ones = Map.get(c, 1, []) |> MapSet.new()
    twos = Map.get(c, 2, []) |> MapSet.new()
    lmore = MapSet.difference(l, ones) |> MapSet.to_list()
    omore = o |> MapSet.difference(twos) |> MapSet.difference(ones) |> MapSet.to_list()

    na =
      case lmore ++ omore do
        [] ->
          acc

        broken ->
          [constraint_invalid("rarity count", from, broken) | acc]
      end

    verify_constraints(rest, di, na)
  end

  defp verify_constraints([{"rune cost", from} | rest], di, acc) do
    rune_spread =
      di
      |> Map.get("runeCost", [])
      |> Enum.reduce(%{"blood" => 0, "frost" => 0, "unholy" => 0}, fn
        {m, _}, a -> Map.merge(a, m, fn _k, v1, v2 -> max(v1, v2) end)
      end)

    tot_runes = rune_spread |> Map.values() |> Enum.sum()

    na =
      cond do
        tot_runes <= 3 ->
          acc

        true ->
          [constraint_invalid("rune cost", from, "Rune spread too wide #{rune_spread}") | acc]
      end

    verify_constraints(rest, di, na)
  end

  defp verify_constraints([{"only odd", from} | rest], %{"cost" => c} = di, acc) do
    fa =
      case Enum.filter(c, fn {k, _v} -> rem(k, 2) == 0 end) do
        [] ->
          :valid

        broken ->
          constraint_invalid("only odd", from, broken)
      end

    verify_constraints(rest, di, [fa | acc])
  end

  defp verify_constraints([{"only even", from} | rest], %{"cost" => c} = di, acc) do
    fa =
      case Enum.filter(c, fn {k, _v} -> rem(k, 2) == 1 end) do
        [] ->
          :valid

        broken ->
          constraint_invalid("only odd", from, broken)
      end

    verify_constraints(rest, di, [fa | acc])
  end

  defp verify_constraints([{"no minion", from} | rest], %{"type" => t} = di, acc) do
    na =
      case Map.get(t, "MINION", []) do
        [] ->
          acc

        broken ->
          [constraint_invalid("no minion", from, broken) | acc]
      end

    verify_constraints(rest, di, na)
  end

  defp verify_constraints([{"no neutral", from} | rest], %{"cardClass" => c} = di, acc) do
    na =
      case Map.get(c, "NEUTRAL", []) do
        [] ->
          acc

        broken ->
          [constraint_invalid("no neutral", from, broken) | acc]
      end

    verify_constraints(rest, di, na)
  end

  defp verify_constraints([{"ten different costs", from} | rest], %{"cost" => c} = di, acc) do
    na =
      case Enum.count(c) do
        g when g >= 10 ->
          acc

        n ->
          [constraint_invalid("ten different costs", from, "Deck has #{n} different costs") | acc]
      end

    verify_constraints(rest, di, na)
  end

  # Will this ever cause a pattern match error?  I don't think so, but we'll see.
  defp verify_constraints(
         [{"all minions same type", from} | rest],
         %{"type" => %{"MINION" => m}, "races" => r} = di,
         acc
       ) do
    case Enum.any?(r, fn {_, rm} -> from == m -- rm end) do
      true ->
        acc

      false ->
        [
          constraint_invalid(
            "all minions same type",
            from,
            "Deck has at least one minion without the proper tag."
          )
          | acc
        ]
    end

    verify_constraints(rest, di, acc)
  end

  defp verify_constraints([{"no two cost", from} | rest], %{"cost" => c} = di, acc) do
    na =
      case Map.get(c, 2, []) -- from do
        [] ->
          acc

        broken ->
          [constraint_invalid("no two cost", from, broken) | acc]
      end

    verify_constraints(rest, di, na)
  end

  defp verify_constraints([{"no three cost", from} | rest], %{"cost" => c} = di, acc) do
    na =
      case Map.get(c, 3, []) -- from do
        [] ->
          acc

        broken ->
          [constraint_invalid("no three cost", from, broken) | acc]
      end

    verify_constraints(rest, di, na)
  end

  defp verify_constraints([{"no four cost", from} | rest], %{"cost" => c} = di, acc) do
    na =
      case Map.get(c, 4, []) -- from do
        [] ->
          acc

        broken ->
          [constraint_invalid("no four cost", from, broken) | acc]
      end

    verify_constraints(rest, di, na)
  end

  defp verify_constraints(
         [{"all shadow spells", from} | rest],
         %{
           "type" => %{"SPELL" => st},
           "spellSchool" => %{"SHADOW" => sss}
         } = di,
         acc
       ) do
    na =
      case st -- sss do
        [] -> acc
        broken -> [constraint_invalid("all shadow spells", from, broken) | acc]
      end

    verify_constraints(rest, di, na)
  end

  defp verify_constraints(
         [{"all nature spells", from} | rest],
         %{
           "type" => %{"SPELL" => st},
           "spellSchool" => %{"NATURE" => sss}
         } = di,
         acc
       ) do
    na =
      case st -- sss do
        [] -> acc
        broken -> [constraint_invalid("all nature spells", from, broken) | acc]
      end

    verify_constraints(rest, di, na)
  end

  defp verify_constraints(
         [{"least expensive minion", from} | rest],
         %{
           "cost" => c,
           "type" => %{"MINION" => m}
         } = di,
         acc
       ) do
    minions = MapSet.new(m)
    # Should only ever be one least expensive
    [compare | _] = from
    {cost, _} = Enum.find(c, fn {_c, i} -> compare in i end)

    cheaper =
      Enum.reduce(c, [], fn
        {c, i}, a when c <= cost -> a ++ i
        _, a -> a
      end)
      |> then(fn c -> c -- from end)
      |> MapSet.new()

    na =
      case MapSet.intersection(cheaper, minions) |> MapSet.to_list() do
        [] -> acc
        broken -> [constraint_invalid("least expensive minion", from, broken) | acc]
      end

    verify_constraints(rest, di, na)
  end

  defp verify_constraints(
         [{"most expensive minion", from} | rest],
         %{
           "cost" => c,
           "type" => %{"MINION" => m}
         } = di,
         acc
       ) do
    minions = MapSet.new(m)
    # Should only ever be one least expensive
    [compare | _] = from
    {cost, _} = Enum.find(c, fn {_c, i} -> compare in i end)

    cheaper =
      Enum.reduce(c, [], fn
        {c, i}, a when c >= cost -> a ++ i
        _, a -> a
      end)
      |> then(fn c -> c -- from end)
      |> MapSet.new()

    na =
      case MapSet.intersection(cheaper, minions) |> MapSet.to_list() do
        [] -> acc
        broken -> [constraint_invalid("most expensive minion", from, broken) | acc]
      end

    verify_constraints(rest, di, na)
  end

  defp verify_constraints([{c, f} | rest], di, acc) do
    verify_constraints(rest, di, [constraint_invalid("unhandled: #{c}", f, "Can't know") | acc])
  end

  defp constraint_invalid(constraint, from, by) do
    [
      constraint: constraint,
      from:
        case from do
          [] -> ["base rules"]
          s when is_binary(s) -> [s]
          l when is_list(l) -> dbfs_to_card_list(l)
        end,
      by:
        case by do
          s when is_binary(s) ->
            [s]

          l when is_list(l) ->
            Enum.reduce(l, %{}, fn
              {k, v}, a -> Map.put(a, k, dbfs_to_card_list(v))
              d, a -> Map.put(a, d, dbfs_to_card_list([d]))
            end)
        end
    ]
  end

  defp dbfs_to_card_list(dbfs) do
    Enum.map(dbfs, fn dbfId ->
      {:ok, c} = HSCards.by_dbf(dbfId)
      c
    end)
  end
end
