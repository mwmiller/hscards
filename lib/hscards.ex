defmodule HSCards do
  @moduledoc """
  Dealing with Hearthstone cards
  """

  @doc """
  Update the card database with the latest cards from the Hearthstone JSON API.
  They are stored in a CubDB database in the `priv` directory of the application.
  """
  def update_cards do
    HSCards.DB.network_update()
  end

  @doc """
  Get card data by dbfId.
  """
  def by_dbf(dbf_id) do
    HSCards.DB.get(dbf_id)
  end

  # Maps both ways for encode and decode
  @formats_map [:unknown, :wild, :standard, :classic, :twist]
               |> Enum.with_index()
               |> Enum.reduce(%{}, fn {a, i}, acc -> acc |> Map.put(i, a) |> Map.put(a, i) end)

  @doc """
  Create a deck from a deckstring.
  """
  def from_deckstring(deckstring) do
    deckstring |> Base.decode64!() |> build_deck
  end

  @doc """
  Turn a deck into a deckstring.
  """
  def to_deckstring(%{format: format, heroes: heroes, maindeck: maindeck} = deck) do
    {singles, doubles, multiples} = split_by_count(maindeck)

    most =
      <<0, 1, Map.get(@formats_map, format, :unknown)>>
      |> add_list(heroes)
      |> add_list(singles)
      |> add_list(doubles)
      |> add_list(multiples)

    # This is the sideboard, which is optional.
    # I considered using a different function head, but it is simpler here because of the
    # Base.encode64/1 call at the end.
    case Map.get(deck, :sideboard) do
      # Pre-sideboard decks have no sideboard.
      nil ->
        most

      # Sideboard codes without an actual sideboard are just a zero byte.
      [] ->
        most <> <<0>>

      sb ->
        {sideboard_singles, sideboard_doubles, sideboard_multiples} =
          split_by_count(sb)

        (most <> <<1>>)
        |> add_list(sideboard_singles)
        |> add_list(sideboard_doubles)
        |> add_list(sideboard_multiples)
    end
    |> Base.encode64()
  end

  def to_deckstring(_) do
    {:error, "Invalid deck format"}
  end

  # This pretty much sucks, but it should be good enough for now.
  defp split_by_count(list) do
    Enum.reduce(list, {[], [], []}, fn card, acc ->
      idx = Map.get(card, "count", 1) - 1

      case idx do
        0 -> {[card | elem(acc, 0)], acc |> elem(1), acc |> elem(2)}
        1 -> {acc |> elem(0), [card | elem(acc, 1)], acc |> elem(2)}
        _ -> {acc |> elem(0), acc |> elem(1), [card | elem(acc, 2)]}
      end
    end)
  end

  defp add_list(curr, list) do
    encode_list(
      curr <> Varint.LEB128.encode(length(list)),
      Enum.sort_by(list, fn e -> e["dbfID"] end)
    )
  end

  defp encode_list(curr, []), do: curr
  # Here, pattern match on the various things to encode properly.
  # We can certainly see how it was cobbled together.
  defp encode_list(curr, [%{"dbfId" => dbfId, "owner" => o, "count" => c} | rest]) when c > 2 do
    encode_list(
      curr <>
        Varint.LEB128.encode(dbfId) <> Varint.LEB128.encode(o) <> Varint.LEB128.encode(c),
      rest
    )
  end

  defp encode_list(curr, [%{"dbfId" => dbfId, "owner" => o} | rest]) do
    encode_list(curr <> Varint.LEB128.encode(dbfId) <> Varint.LEB128.encode(o), rest)
  end

  defp encode_list(curr, [%{"dbfId" => dbfId, "count" => c} | rest]) when c > 2 do
    encode_list(curr <> Varint.LEB128.encode(dbfId) <> Varint.LEB128.encode(c), rest)
  end

  defp encode_list(curr, [%{"dbfId" => dbfId} | rest]) do
    encode_list(curr <> Varint.LEB128.encode(dbfId), rest)
  end

  defp build_deck(<<0, 1, format::integer-size(8), bytes::binary>>) do
    stack_deck({bytes, %{format: Map.get(@formats_map, format, :undefined)}})
  end

  defp stack_deck({<<>>, out}), do: out

  defp stack_deck(inc) do
    main =
      inc
      |> grab({:heroes, :maindeck})
      |> grab({:singles, :maindeck})
      |> grab({:doubles, :maindeck})
      |> grab({:multiples, :maindeck})

    # We don't know what to do with the rest of the bytes, if any
    # so we just ignore them
    {_, final_deck} =
      case main do
        {<<1::8, rest::binary>>, deck} ->
          {rest, deck}
          |> grab({:singles, :sideboard})
          |> grab({:doubles, :sideboard})
          |> grab({:triples, :sideboard})

        {<<0::8>>, deck} ->
          {<<>>, Map.put(deck, :sideboard, [])}

        {other, deck} ->
          {other, deck}
      end

    final_deck
  end

  defp grab({bytes, deck}, which) do
    {count, rest} = Varint.LEB128.decode(bytes)
    grab({rest, deck}, which, count)
  end

  defp grab(out, _which, 0), do: out

  defp grab({bytes, deck}, which, count) do
    {dbfId, maybemore} = Varint.LEB128.decode(bytes)

    {meta, rest, key} =
      case which do
        {:heroes, _} ->
          {%{"count" => 1}, maybemore, :heroes}

        {:singles, :maindeck} ->
          {%{"count" => 1}, maybemore, :maindeck}

        {:singles, :sideboard} ->
          {owner, ongoing} = Varint.LEB128.decode(maybemore)
          {%{"count" => 1, "owner" => owner}, ongoing, :sideboard}

        {:doubles, :maindeck} ->
          {%{"count" => 2}, maybemore, :maindeck}

        {:doubles, :sideboard} ->
          {owner, ongoing} = Varint.LEB128.decode(maybemore)
          {%{"count" => 2, "owner" => owner}, ongoing, :sideboard}

        {:multiples, :maindeck} ->
          {howmany, ongoing} = Varint.LEB128.decode(maybemore)
          {%{"count" => howmany}, ongoing, :sideboard}

        {:multiples, :sideboard} ->
          {owner, ongoing} = Varint.LEB128.decode(maybemore)
          {howmany, andon} = Varint.LEB128.decode(ongoing)
          {%{"count" => howmany, "owner" => owner}, andon, :sideboard}
      end

    card =
      case by_dbf(dbfId) do
        {:ok, c} -> Map.merge(c, meta)
        {:error, err} -> Map.merge(%{"type" => err}, meta)
      end

    grab({rest, Map.update(deck, key, [card], fn cs -> [card | cs] end)}, which, count - 1)
  end

  @stats_fields [
    "cardClass",
    "classes",
    "rarity",
    "cost",
    "health",
    "attack",
    "set",
    "type",
    "spellSchool",
    "mechanics"
  ]

  @doc """
  Report on distribution of cards.
  The key into the structure defaults to `:maindeck`
  """
  def deck_stats(cards, which \\ :maindeck) do
    # Decks should always be small enough that these multiple passes are not a problem
    gather_fields(@stats_fields, cards[which], %{})
  end

  defp gather_fields([], _cards, histo), do: histo

  defp gather_fields([field | rest], cards, histo) do
    new_histo = Map.merge(histo, %{field => gather_field(field, cards)})
    gather_fields(rest, cards, new_histo)
  end

  defp gather_field(field, deck) do
    deck
    |> Enum.reduce(%{}, fn card, acc ->
      case Map.get(card, field) do
        nil -> acc
        l when is_list(l) -> Enum.reduce(l, acc, fn e, a -> Map.update(a, e, 1, &(&1 + 1)) end)
        v -> Map.update(acc, v, 1, &(&1 + 1))
      end
    end)
  end
end
