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

  def deckstring_to_cards(deckstring) do
    deckstring |> Base.decode64!() |> build_deck
  end

  defp build_deck(<<0, 1, format::integer-size(8), bytes::binary>>) do
    fa =
      case format do
        0 -> :unknown
        1 -> :wild
        2 -> :standard
        3 -> :classic
        4 -> :twist
        _ -> :undefined
      end

    stack_deck({bytes, %{format: fa}})
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
  Gather fields from the deck into a histogram.
  The key into the deck structure is defaults to `:maindeck`, but can be set to `:sideboard` as well.
  """
  def field_stats(deck, which \\ :maindeck) do
    # Decks should always be small enough that these multiple passes are not a problem
    gather_fields(@stats_fields, deck[which], %{})
  end

  defp gather_fields([], _deck, histo), do: histo

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
