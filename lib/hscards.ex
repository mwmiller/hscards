defmodule HSCards do
  @moduledoc """
  Dealing with Hearthstone cards
  """

  @cards_endpoint "https://api.hearthstonejson.com/v1/latest/enUS/cards.json"
  @cards_by_dbf Path.join([:code.priv_dir(:hscards), "cards.json"])
                |> Path.expand()
                |> File.read!()
                |> :json.decode()
                |> Enum.reduce(%{}, fn card, acc ->
                  Map.put(acc, card["dbfId"], card)
                end)
  @doc """
  Update the card database with the latest cards from the Hearthstone JSON API.

  Right now the cards are simply stored in the JSON and structured as a list of maps.
  """
  def update_cards do
    with {:ok, {{_, 200, _}, _headers, json}} <- :httpc.request(@cards_endpoint) do
      Path.join([:code.priv_dir(:hscards), "cards.json"]) |> Path.expand() |> File.write!(json)
      {:ok, "Cards updated successfully."}
    else
      err -> {:error, "Failed to fetch cards: #{err}"}
    end
  end

  @doc """
  Get card data by dbfId.
  """
  def by_dbf(dbf_id) do
    case Map.get(@cards_by_dbf, dbf_id) do
      nil -> {:error, "Card not found dbfID: #{dbf_id}"}
      card -> {:ok, card}
    end
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
end
