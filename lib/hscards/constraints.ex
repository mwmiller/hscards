defmodule HSCards.Constraints do
  @moduledoc """
  Deck building constraints reified
  """
  # String keys for less marshalling
  # This associates with the functions, we'll see if we can find a way to combine
  @empty_ms MapSet.new()
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
    "tourist deck" => %{
      text_match: "tourist",
      constrained: ["cardClass", "set"]
    },
    "base rules" => %{constrained: ["runeCost", "count", "rarity", "cardClass", "classes"]},
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
  @base_checks [
    {"deck size thirty", []},
    {"rarity count", []},
    {"rune cost", []},
    {"card classes", []}
  ]

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

  defp verify_constraints([{"deck size forty", _from} | rest], %{"count" => c} = di, acc) do
    card_count =
      Enum.reduce(c, 0, fn {count, cards}, a -> a + count * MapSet.size(cards) end)

    verify_constraints(
      rest -- [{"deck size thirty", []}],
      di,
      accumulate_violations(card_count != 40, "Improper deck size of #{card_count} cards", acc)
    )
  end

  defp verify_constraints([{"deck size thirty", _from} | rest], %{"count" => c} = di, acc) do
    card_count =
      Enum.reduce(c, 0, fn {count, cards}, a -> a + count * MapSet.size(cards) end)

    verify_constraints(
      rest -- [{"deck size thirty", []}],
      di,
      accumulate_violations(card_count != 30, "Improper deck size of #{card_count} cards", acc)
    )
  end

  defp verify_constraints([{"no dupe", from} | rest], %{"count" => c} = di, acc) do
    verify_constraints(
      rest -- [{"rarity count", []}],
      di,
      accumulate_violations(Enum.filter(c, fn {k, _v} -> k != 1 end), from, acc)
    )
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

    ones = Map.get(c, 1, @empty_ms)
    twos = Map.get(c, 2, @empty_ms)
    lmore = MapSet.difference(l, ones)
    omore = o |> MapSet.difference(twos) |> MapSet.difference(ones)

    verify_constraints(rest, di, accumulate_violations(MapSet.union(lmore, omore), from, acc))
  end

  defp verify_constraints(
         [{"tourist deck", from} | rest],
         %{"heroes" => h, "cardClass" => c, "set" => s} = di,
         acc
       ) do
    case MapSet.to_list(from) do
      [tourist] ->
        # We have a single tourist, so we can check the deck
        dest = tourist_dest(tourist)
        touring = c |> Map.get(dest, @empty_ms)
        toured = s |> Map.get("ISLAND_VACATION", @empty_ms)
        [%{"cardClass" => hero_class}] = h

        verify_constraints(
          rest -- [{"card classes", []}],
          di,
          accumulate_violations(
            recon_classes(di, hero_class, [dest])
            |> MapSet.union(touring)
            |> MapSet.difference(toured),
            from,
            acc
          )
        )

      broken ->
        # We have more than one tourist, so we don't check the deck
        verify_constraints(
          rest -- [{"card classes", []}],
          di,
          accumulate_violations(
            "Tourist deck must have exactly one tourist, got #{Enum.count(broken)}",
            from,
            acc
          )
        )
    end
  end

  defp verify_constraints(
         [{"card classes", from} | rest],
         %{"heroes" => h} = di,
         acc
       ) do
    # For now we'll let it crash if they have more than one hero class
    [%{"cardClass" => hero_class}] = h

    verify_constraints(
      rest,
      di,
      accumulate_violations(recon_classes(di, hero_class), from, acc)
    )
  end

  defp verify_constraints([{"rune cost", _from} | rest], di, acc) do
    rune_spread =
      di
      |> Map.get("runeCost", [])
      |> Enum.reduce(%{"blood" => 0, "frost" => 0, "unholy" => 0}, fn
        {m, _}, a -> Map.merge(a, m, fn _k, v1, v2 -> max(v1, v2) end)
      end)

    tote_runes = rune_spread |> Map.values() |> Enum.sum()

    verify_constraints(
      rest,
      di,
      accumulate_violations(tote_runes > 3, "Rune spread too wide: #{tote_runes} runes", acc)
    )
  end

  defp verify_constraints([{"only odd", from} | rest], %{"cost" => c} = di, acc) do
    verify_constraints(
      rest,
      di,
      accumulate_violations(
        Enum.reduce(c, @empty_ms, fn
          {k, _v}, a when rem(k, 2) == 1 -> a
          {_k, v}, a -> MapSet.union(a, v)
        end),
        from,
        acc
      )
    )
  end

  defp verify_constraints([{"only even", from} | rest], %{"cost" => c} = di, acc) do
    verify_constraints(
      rest,
      di,
      accumulate_violations(
        Enum.reduce(c, @empty_ms, fn
          {k, _v}, a when rem(k, 2) == 0 -> a
          {_k, v}, a -> MapSet.union(a, v)
        end),
        from,
        acc
      )
    )
  end

  defp verify_constraints([{"no minion", from} | rest], %{"type" => t} = di, acc) do
    verify_constraints(
      rest,
      di,
      accumulate_violations(Map.get(t, "MINION", @empty_ms), from, acc)
    )
  end

  defp verify_constraints([{"no neutral", from} | rest], %{"cardClass" => c} = di, acc) do
    verify_constraints(
      rest,
      di,
      accumulate_violations(Map.get(c, "NEUTRAL", @empty_ms), from, acc)
    )
  end

  defp verify_constraints([{"ten different costs", from} | rest], %{"cost" => c} = di, acc) do
    count = Enum.count(c)

    verify_constraints(rest, di, accumulate_violations(count < 10, from, acc))
  end

  # Will this ever cause a pattern match error?  I don't think so, but we'll see.
  defp verify_constraints(
         [{"all minions same type", from} | rest],
         %{"type" => %{"MINION" => m}, "races" => r} = di,
         acc
       ) do
    ominions =
      from
      |> MapSet.to_list()
      |> Enum.reduce(m, fn
        i, a -> MapSet.delete(a, i)
      end)

    verify_constraints(
      rest,
      di,
      accumulate_violations(
        Enum.any?(r, fn {_, rm} -> ominions |> MapSet.difference(rm) |> MapSet.size() != 0 end),
        "Deck has at least one minion without the shared tribe.",
        acc
      )
    )
  end

  defp verify_constraints([{"no two cost", from} | rest], %{"cost" => c} = di, acc) do
    verify_constraints(
      rest,
      di,
      accumulate_violations(MapSet.difference(Map.get(c, 2, @empty_ms), from), from, acc)
    )
  end

  defp verify_constraints([{"no three cost", from} | rest], %{"cost" => c} = di, acc) do
    verify_constraints(
      rest,
      di,
      accumulate_violations(MapSet.difference(Map.get(c, 3, @empty_ms), from), from, acc)
    )
  end

  defp verify_constraints([{"no four cost", from} | rest], %{"cost" => c} = di, acc) do
    verify_constraints(
      rest,
      di,
      accumulate_violations(MapSet.difference(Map.get(c, 4, @empty_ms), from), from, acc)
    )
  end

  defp verify_constraints(
         [{"all shadow spells", from} | rest],
         %{
           "type" => %{"SPELL" => st},
           "spellSchool" => %{"SHADOW" => sss}
         } = di,
         acc
       ) do
    verify_constraints(rest, di, accumulate_violations(MapSet.difference(st, sss), from, acc))
  end

  defp verify_constraints(
         [{"all nature spells", from} | rest],
         %{
           "type" => %{"SPELL" => st},
           "spellSchool" => %{"NATURE" => nss}
         } = di,
         acc
       ) do
    verify_constraints(rest, di, accumulate_violations(MapSet.difference(st, nss), from, acc))
  end

  defp verify_constraints(
         [{"least expensive minion", from} | rest],
         %{
           "cost" => c,
           "type" => %{"MINION" => m}
         } = di,
         acc
       ) do
    # Should only ever be one least expensive
    [compare | _] = MapSet.to_list(from)
    {cost, _} = Enum.find(c, fn {_c, i} -> compare in i end)

    cheaper =
      Enum.reduce(c, @empty_ms, fn
        {c, i}, a when c <= cost -> MapSet.union(a, i)
        _, a -> a
      end)
      |> then(fn c -> MapSet.difference(c, from) end)

    verify_constraints(
      rest,
      di,
      accumulate_violations(MapSet.intersection(cheaper, m), from, acc)
    )
  end

  defp verify_constraints(
         [{"most expensive minion", from} | rest],
         %{
           "cost" => c,
           "type" => %{"MINION" => m}
         } = di,
         acc
       ) do
    [compare | _] = MapSet.to_list(from)
    {cost, _} = Enum.find(c, fn {_c, i} -> compare in i end)

    costlier =
      Enum.reduce(c, @empty_ms, fn
        {c, i}, a when c >= cost -> MapSet.union(a, i)
        _, a -> a
      end)
      |> then(fn c -> MapSet.difference(c, from) end)

    verify_constraints(
      rest,
      di,
      accumulate_violations(MapSet.intersection(costlier, m), from, acc)
    )
  end

  defp verify_constraints([{c, f} | rest], di, acc) do
    verify_constraints(rest, di, accumulate_violations("unhandled: #{c}", f, acc))
  end

  defp accumulate_violations([], _from, acc), do: acc
  defp accumulate_violations(false, _from, acc), do: acc

  defp accumulate_violations(true, from, acc) do
    [constraint_invalid(from, "Constraint violated") | acc]
  end

  defp accumulate_violations(message, from, acc) when is_binary(message) do
    [constraint_invalid(from, message) | acc]
  end

  defp accumulate_violations(%MapSet{} = val, from, acc) do
    case MapSet.size(val) do
      0 -> acc
      _ -> [constraint_invalid(from, val) | acc]
    end
  end

  defp constraint_invalid(from, by) do
    [
      from:
        case from do
          [] -> ["base rules"]
          s when is_binary(s) -> [s]
          l -> dbfs_to_card_list(l)
        end,
      by:
        case by do
          s when is_binary(s) ->
            [s]

          l when is_list(l) or is_map(l) ->
            Enum.reduce(l, [], fn
              {_k, v}, a -> a ++ dbfs_to_card_list(v)
              d, a -> a ++ dbfs_to_card_list([d])
            end)
        end
    ]
  end

  defp recon_classes(deck_info, hero_class, extra_classes \\ [])

  defp recon_classes(di, hero_class, extra_classes) do
    cc = Map.get(di, "cardClass", [])

    rec =
      di
      |> Map.get("classes", %{})
      |> Enum.reduce(cc, fn
        {k, v}, a ->
          Map.update(a, k, v, fn existing -> MapSet.union(existing, v) end)
      end)

    rec
    |> Map.drop([hero_class, "NEUTRAL"] ++ extra_classes)
    |> Map.values()
    |> Enum.reduce(@empty_ms, fn v, a ->
      MapSet.union(a, v)
    end)
    |> then(fn v -> MapSet.difference(v, rec[hero_class]) end)
  end

  defp tourist_dest(dbf) do
    # This is a bit of a hack, but it works for now
    case HSCards.by_dbf(dbf) do
      {:ok, %{"text" => t}} ->
        case Regex.named_captures(~r/<b>(?<dest>.*) Tourist/, t) do
          %{"dest" => dest} -> dest |> String.upcase() |> String.trim()
          _ -> "UNKNOWN"
        end

      _ ->
        "UNKNOWN"
    end
  end

  defp dbfs_to_card_list(dbfs) when is_list(dbfs) do
    Enum.map(dbfs, fn dbfId ->
      {:ok, c} = HSCards.by_dbf(dbfId)
      c
    end)
  end

  defp dbfs_to_card_list(%MapSet{} = dbfs) do
    dbfs
    |> MapSet.to_list()
    |> dbfs_to_card_list()
  end
end
