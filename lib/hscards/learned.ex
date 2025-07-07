defmodule HSCards.Learned do
  @moduledoc """
  Card learnings
  """

  import Ecto.Query
  import SqliteVec.Ecto.Query

  @default_similar_options [
    same_cost: false,
    same_class: false,
    same_type: false,
    sets: :all,
    limit: 5
  ]
  @doc """
  List the default similar options
  """
  def default_similar_options, do: @default_similar_options

  @doc """
  Find similar cards using a vector embedding
  NO warranty is provided including fitness for purpose
  Options may be set to filter the results

  Options:
  - `limit` - an integer max number of results to return, or `:all`
  - `sets` - a list of acceptable sets from which to select, or `:all`
  - `same_class` - a boolean to indicate whether the same class or "NEUTRAL"
  - `same_cost` - a boolean to indicate whether to filter by the same card cost
  - `same_type` - a booleanr to indicate whether to filter by the same card type

  Returns a list of card maps
  """
  def similar_cards(card, options \\ [])

  def similar_cards(%{"dbfId" => match_dbf} = card, options) do
    opt = Keyword.merge(@default_similar_options, options)

    case HSCards.Repo.one(from(i in HSCards.Embedding, where: i.dbfId == ^match_dbf)) do
      %{embedding: v} ->
        res =
          HSCards.Repo.all(
            from(i in HSCards.Embedding,
              join: c in HSCards.Card,
              on: i.dbfId == c.dbfId,
              where: i.dbfId != ^match_dbf,
              select: c.full_info,
              order_by: vec_distance_L2(i.embedding, vec_f32(v))
            )
          )
          |> filter_by(card, opt)

        # The filters are easier to apply once we have the card data
        # than in trying to work out the query or sets are smallish (under 8k)

        {:ok, res}

      _ ->
        {:error, "Improper card match"}
    end
  end

  def similar_cards(_, _), do: {:error, "Improper card"}

  defp filter_by(acc, _card, []), do: acc
  # No-ops go here
  defp filter_by(acc, card, [{:limit, :all} | rest]), do: filter_by(acc, card, rest)
  defp filter_by(acc, card, [{:same_cost, false} | rest]), do: filter_by(acc, card, rest)
  defp filter_by(acc, card, [{:same_class, false} | rest]), do: filter_by(acc, card, rest)
  defp filter_by(acc, card, [{:same_type, false} | rest]), do: filter_by(acc, card, rest)
  defp filter_by(acc, card, [{:sets, :all} | rest]), do: filter_by(acc, card, rest)

  defp filter_by(acc, %{"cost" => n} = card, [{:same_cost, true} | rest]) do
    acc
    |> Enum.filter(fn c -> c["cost"] == n end)
    |> filter_by(card, rest)
  end

  defp filter_by(acc, %{"cardClass" => class} = card, [{:same_class, true} | rest]) do
    acc
    |> Enum.filter(fn c -> c["cardClass"] in [class, "NEUTRAL"] end)
    |> filter_by(card, rest)
  end

  defp filter_by(acc, %{"type" => type} = card, [{:same_type, true} | rest]) do
    acc
    |> Enum.filter(fn c -> c["type"] == type end)
    |> filter_by(card, rest)
  end

  defp filter_by(acc, card, [{:sets, sets} | rest]) when is_list(sets) do
    acc
    |> Enum.filter(fn c -> c["set"] in sets end)
    |> filter_by(card, rest)
  end

  # Limit is always processed last if it is an integer
  defp filter_by(acc, _card, [{:limit, n}]) when is_integer(n), do: Enum.take(acc, n)
  # We'll hope they didn't supply legal ones twice
  defp filter_by(acc, card, [{:limit, n} | rest]) when is_integer(n),
    do: filter_by(acc, card, rest ++ [{:limit, n}])

  defp filter_by(acc, card, [_ | rest]), do: filter_by(acc, card, rest)

  @comparables [
    "armor",
    "attack",
    "cardClass",
    "classes",
    "constraint",
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

  @doc """
  Generate the embeddings map for all known collectible cards.
  This is mainly useful for the `HSCards.DB` to store them for later use
  """
  def embeddings_map() do
    {:ambiguous, cards} = HSCards.DB.find(%{collectible: true})

    {filled, defaults} =
      cards
      |> proper_keys
      |> add_missing

    ordered = Map.keys(defaults) |> Enum.sort()
    prefille = List.duplicate(0.0, @embedding_size - length(ordered))

    Enum.reduce(filled, [], fn c, a ->
      [[dbfId: c["dbfId"], embedding: SqliteVec.Float32.new(embedding(ordered, c, prefille))] | a]
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
