defmodule HSCards.Learned do
  @moduledoc """
  Card learnings
  """

  @comparables [
    "armor",
    "attack",
    "cardClass",
    "classes",
    "cost",
    "dbfId",
    "durability",
    "elite",
    "faction",
    "health",
    "mechanics",
    "overload",
    "race",
    "races",
    "rarity",
    "referencedTags",
    "runeCost",
    "set",
    "spellDamage",
    "spellSchool",
    "type"
  ]
  @cd_ms MapSet.new(@comparables)
  @embedding_size 512

  def embeddings_map() do
    {:ambiguous, cards} = HSCards.DB.find(%{collectible: true})

    {filled, defaults} =
      cards
      |> proper_keys
      |> add_missing

    ordered = Map.keys(defaults) |> Enum.sort()
    prefille = List.duplicate(0.0, @embedding_size - length(ordered))
    IO.inspect(Enum.count(ordered))

    Enum.reduce(filled, %{}, fn c, a ->
      Map.put(a, c["dbfId"], embedding(ordered, c, prefille))
    end)
  end

  defp embedding([], _c, acc), do: acc

  defp embedding([f | ield], c, acc) do
    embedding(ield, c, [c[f] * 1.0 | acc])
  end

  defp add_missing(proper_out, acc \\ [])
  defp add_missing({[], d}, acc), do: {acc, d}

  defp add_missing({[card | rest], defaults}, acc) do
    add_missing({rest, defaults}, [Map.merge(defaults, card) | acc])
  end

  defp proper_keys(cards, acc \\ {[], %{}})
  defp proper_keys([], acc), do: acc

  defp proper_keys([card | rest], {cards, keys}) do
    droppable =
      card
      |> Map.keys()
      |> MapSet.new()
      |> MapSet.difference(@cd_ms)

    comparable =
      card
      |> Map.drop(MapSet.to_list(droppable))
      |> then(fn c -> Map.merge(defaults(@comparables), c) end)

    {nc, nk} =
      Enum.reduce(comparable, {%{}, keys}, fn c, {cs, ks} ->
        {uc, uk} = expand_keys(c, ks)
        {Map.merge(cs, uc), uk}
      end)

    proper_keys(rest, {[nc | cards], nk})
  end

  defp defaults(list) do
    Enum.reduce(list, %{}, fn k, a -> Map.put(a, k, -1) end)
  end

  defp ekey(list), do: Enum.join(list, "_")

  defp expand_keys({k, v}, vals) when is_list(v) do
    case v do
      [] ->
        {%{k => -1}, vals}

      list ->
        Enum.reduce(list, {%{k => 1}, vals}, fn v, {m, vs} ->
          nk = ekey([k, v])
          {Map.put(m, nk, 1), Map.put(vs, nk, -1)}
        end)
    end
  end

  defp expand_keys({k, v}, vals) when is_map(v) do
    case map_size(v) do
      0 ->
        {%{k => -1}, vals}

      _ ->
        Enum.reduce(v, {%{k => 1}, vals}, fn {ik, iv}, {m, vs} ->
          nk = ekey([k, ik, iv])
          {Map.put(m, nk, 1), Map.put(vs, nk, -1)}
        end)
    end
  end

  defp expand_keys({k, v}, vals) when is_binary(v) do
    nk = ekey([k, v])
    {%{nk => 1}, Map.put(vals, nk, -1)}
  end

  defp expand_keys({k, v}, vals) do
    {%{k => v}, vals}
  end
end
