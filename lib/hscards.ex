defmodule HSCards do
  @moduledoc """
  Dealing with Hearthstone cards
  """

  alias HSCards.{DB, Deck, Sets}

  @doc """
  Update the card database with the latest cards from the Hearthstone JSON API.
  They are stored in an SQLite database in priv
  """
  def sync_to_latest_db do
    DB.update_from_sources()
  end

  # Get card data by dbfId.
  def by_dbf(dbf_id) do
    case DB.find(%{dbfId: dbf_id}) do
      {:ambiguous, cards} ->
        {:error, "Multiple #{length(cards)} cards found with dbfId #{dbf_id}"}

      dbresult ->
        dbresult
    end
  end

  @doc """
  Get card data by name.
  """
  def by_name(name), do: DB.find(%{name: name})

  @doc """
  Get card data by artist.
  """
  def by_artist(artist), do: DB.find(%{artist: artist})

  @doc """
  Get card data by flavor text.
  """
  def by_flavor(flavor), do: DB.find(%{flavor: flavor})

  # Maps both ways for encode and decode
  @formats_map [:unknown, :wild, :standard, :classic, :twist]
               |> Enum.with_index()
               |> Enum.reduce(%{}, fn {a, i}, acc -> acc |> Map.put(i, a) |> Map.put(a, i) end)

  @doc """
  Create a deck from a deckstring.
  """
  def from_deckstring(deckstring) do
    case deckstring |> Base.decode64() do
      :error -> {:error, "Deckstring not properly encoded"}
      {:ok, bytes} -> build_deck(bytes)
    end
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

  def to_deckstring(_), do: {:error, "Invalid deck format"}

  @doc """
  Produce a markdown representation of a deck.
  Also accepts a deckstring, which is decoded first.
  """
  def to_markdown(deck) when is_binary(deck), do: from_deckstring(deck) |> to_markdown()

  def to_markdown(deck) do
    mapped_sb = map_sideboard(Map.get(deck, :sideboard, []), %{})
    sorted_deck = Deck.normalize(deck)

    md_format(deck) <>
      md_heroes(deck.heroes) <>
      md_meta(deck) <>
      md_deck(sorted_deck, -1, mapped_sb, "")
  end

  defp map_sideboard([], acc), do: acc

  defp map_sideboard([card | rest], acc) do
    map_sideboard(
      rest,
      Map.update(acc, card["owner"], [card], fn existing ->
        [card | existing]
      end)
    )
  end

  # {craft, disenchant}
  @crafting %{
    "COMMON" => {40, 5},
    "RARE" => {100, 20},
    "EPIC" => {400, 100},
    "LEGENDARY" => {1600, 400}
  }

  defp md_meta(deck) do
    %{"rarity" => vals, "cost" => cost} = deck |> stats
    deck_rcs = deck_rcs(deck)

    manas =
      cost
      |> Enum.reduce({0, 0, 0, 0, 0, 0, 0, 0}, fn {m, c}, acc ->
        idx = Enum.min([7, m])
        prev = elem(acc, idx)
        acc |> Tuple.delete_at(idx) |> Tuple.insert_at(idx, prev + c)
      end)

    spark =
      case HSCards.Spark.plot(manas) do
        {:ok, spark} -> spark
        _ -> ""
      end

    {deck_cost, deck_value} =
      Enum.reduce(vals, {0, 0}, fn {rarity, count}, acc ->
        {cost, disenchant} = Map.get(@crafting, rarity, 0)
        {elem(acc, 0) + cost * count, elem(acc, 1) + disenchant * count}
      end)

    """
    ## Dust to Create: #{number_sep(deck_cost)} / Disenchant: #{number_sep(deck_value)}
    ## Mana Curve: #{spark}
    #{deck_rcs}
    """
  end

  defp number_sep(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.replace(~r/(?<=\d)(?=(\d{3})+(?!\d))/, ",")
  end

  defp md_deck([], _cost, _sideboard, curr), do: curr

  defp md_deck([card | rest], prev_cost, sideboard, curr) do
    cost = card["cost"]

    cost_header =
      case cost do
        ^prev_cost ->
          ""

        _ ->
          """
          ---
          ### Cost: #{cost}
          ---
          """
      end

    base = "- #{card_rcs(card)}#{card["name"]} (#{card["count"]}x)"

    earn =
      case card["howtoEarn"] do
        nil -> ""
        howto -> " (#{howto})"
      end

    earn_golden =
      case card["howtoEarnGolden"] do
        nil -> ""
        howto -> " (Golden: #{howto})"
      end

    owns =
      case Map.get(sideboard, card["dbfId"]) do
        nil ->
          "\n"

        side_cards ->
          Enum.reduce(side_cards, ":\n", fn side_card, acc ->
            acc <>
              "  - #{card_rcs(side_card)}#{side_card["name"]} (#{side_card["count"]}x #{side_card["cost"]} mana)\n"
          end)
      end

    md_deck(rest, cost, sideboard, curr <> cost_header <> base <> earn <> earn_golden <> owns)
  end

  defp md_format(deck) do
    format_desc =
      case Map.get(deck, :zodiac) do
        %{name: z} -> " (#{z})"
        _ -> ""
      end

    """
    ## Format: #{deck.format |> to_string |> String.capitalize()}#{format_desc}
    """
  end

  defp md_heroes(heroes) when length(heroes) == 1 do
    [hero] = heroes

    """
    ## Class: #{hero["cardClass"] |> String.downcase() |> String.capitalize()} - #{hero["name"]}
    """
  end

  defp md_heroes(heroes) do
    """
    ### Classes: #{heroes |> Enum.map(& &1["cardClass"]) |> Enum.join(", ")}

    """
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

  defp build_deck(_), do: {:error, "Not a proper deckstring"}

  defp stack_deck({<<>>, out}), do: out

  defp stack_deck(inc) do
    main =
      inc
      |> grab({:heroes, :heroes})
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

    final_deck |> Sets.add_deck_info()
  end

  defp grab({bytes, deck}, which) do
    {count, rest} = Varint.LEB128.decode(bytes)
    grab({rest, deck, []}, which, count)
  end

  defp grab({rest, deck, these}, {_, key}, 0) do
    {rest, Map.update(deck, key, these, fn d -> d ++ these end)}
  end

  defp grab({bytes, deck, these}, which, count) do
    {dbfId, maybemore} = Varint.LEB128.decode(bytes)

    {meta, rest} =
      case which do
        {:heroes, _} ->
          {%{"count" => 1}, maybemore}

        {:singles, :maindeck} ->
          {%{"count" => 1}, maybemore}

        {:singles, :sideboard} ->
          {owner, ongoing} = Varint.LEB128.decode(maybemore)
          {%{"count" => 1, "owner" => owner}, ongoing}

        {:doubles, :maindeck} ->
          {%{"count" => 2}, maybemore}

        {:doubles, :sideboard} ->
          {owner, ongoing} = Varint.LEB128.decode(maybemore)
          {%{"count" => 2, "owner" => owner}, ongoing}

        {:multiples, :maindeck} ->
          {howmany, ongoing} = Varint.LEB128.decode(maybemore)
          {%{"count" => howmany}, ongoing}

        {:multiples, :sideboard} ->
          {owner, ongoing} = Varint.LEB128.decode(maybemore)
          {howmany, andon} = Varint.LEB128.decode(ongoing)
          {%{"count" => howmany, "owner" => owner}, andon}
      end

    card =
      case by_dbf(dbfId) do
        {:ok, c} -> Map.merge(c, meta)
        {:error, err} -> Map.merge(%{"type" => err}, meta)
      end

    grab({rest, deck, [card | these]}, which, count - 1)
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
  Report on distribution of cards in a deck.
  For convenience, it accepts a deck or a deckstring.
  """
  def stats(deck) when is_binary(deck) do
    deck |> from_deckstring() |> stats()
  end

  def stats(deck) do
    cards = deck.maindeck ++ Map.get(deck, :sideboard, [])
    # Decks should always be small enough that these multiple passes are not a problem
    gather_fields(@stats_fields, cards, %{})
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

  defp card_rcs(%{"runeCost" => rune_cost_map}) do
    case rune_cost_string(rune_cost_map) do
      "" -> ""
      str -> "(#{str}) "
    end
  end

  defp card_rcs(_), do: ""

  @doc """
  Convert a rune cost map to a string representation.
  """

  def rune_cost_string(rune_cost_map) do
    case inv_map(rune_cost_map) do
      [{3, rune}] ->
        "tri-#{rune}"

      [{2, rune}] ->
        c = upfirst(rune)
        "#{c}#{c}"

      [{2, primary}, {1, secondary}] ->
        p = upfirst(primary)
        "#{p}#{p}#{upfirst(secondary)}"

      [{1, rune}] ->
        "#{upfirst(rune)}"

      [{1, p}, {1, s}] ->
        "#{upfirst(p)}#{upfirst(s)}"

      [{1, _}, {1, _}, {1, _}] ->
        "rainbow"

      [] ->
        ""

      # Hopefully this never appears in the database, but
      # we might find it via a deckstring.
      _ ->
        "invalid"
    end
  end

  defp upfirst(string) when is_binary(string) do
    string |> String.first() |> String.upcase()
  end

  defp upfirst(_), do: ""

  defp inv_map(map) when is_map(map) do
    map
    |> Enum.reduce([], fn
      {_, 0}, acc -> acc
      {k, v}, acc -> [{v, k} | acc]
    end)
    |> Enum.sort(:desc)
  end

  defp inv_map(_), do: []

  def deck_rcs(deck) do
    case gather_rcs(deck.maindeck ++ deck.sideboard, %{"blood" => 0, "frost" => 0, "unholy" => 0})
         |> rune_cost_string() do
      "" ->
        ""

      rcs ->
        """
            ## Rune Requirements: #{rcs}
        """
    end
  end

  # This is a little silly, but whatever
  defp gather_rcs([], acc), do: acc

  defp gather_rcs([card | rest], %{"blood" => bo, "frost" => fo, "unholy" => uo} = acc) do
    case Map.get(card, "runeCost") do
      %{"blood" => b, "frost" => f, "unholy" => u} ->
        gather_rcs(rest, %{"blood" => max(bo, b), "frost" => max(fo, f), "unholy" => max(uo, u)})

      _ ->
        gather_rcs(rest, acc)
    end
  end

  @default_mutate_options [count: 5, retries: 5]
  @doc """
  The default options to `mutate/2`
  """
  def default_mutate_options, do: @default_mutate_options

  @doc """
  Mutate a supplied deck into something similar-ish.
  Will also take a deckstring for convenience

  Options:
  -  `count`: an integer expressing how many cards to change
  - `reries`: an integer expressing how many times to retry if the result is invalid

  Also can supply options for `HSCards.Learned.similar_card` to manage the way in which
  cards are mutated.  For standard decks, the `sets` option will be automatically set on your behalf.
  """
  def mutate(deck, options \\ [])
  def mutate(deck, options) when is_binary(deck), do: deck |> from_deckstring |> mutate(options)

  def mutate(deck, options) do
    sim_options =
      case Map.get(deck, :zodiac) do
        %{sets: sets} -> [same_class: true, sets: Enum.map(sets, fn s -> s.code end)]
        _ -> [same_class: true]
      end

    # If they provide their oen set info, it will override ours
    {count, sim_opts} =
      @default_mutate_options
      |> Keyword.merge(sim_options)
      |> Keyword.merge(options)
      |> Keyword.pop(:count)

    do_mutate(deck, sim_opts, %{add: [], drop: []}, count)
  end

  defp do_mutate(deck, opts, %{add: add, drop: drop} = acc, 0) do
    case Deck.validate(%{deck | maindeck: (deck.maindeck ++ add) -- drop}) do
      {:invalid, how} ->
        case Keyword.get_and_update(opts, :retries, fn v -> {v, v - 1} end) do
          {1, _} -> {:failure, how}
          {_, newopts} -> mutate(deck, newopts)
        end

      {:valid, final_deck} ->
        Map.merge(acc, %{deck: final_deck, deckstring: to_deckstring(final_deck)})
    end
  end

  defp do_mutate(%{maindeck: md} = deck, opts, %{add: add, drop: drop} = acc, count) do
    possible = Enum.random(md)

    case HSCards.Learned.similar_cards(possible, opts) do
      {:ok, cards} ->
        pick = Enum.find(cards, fn c -> c not in drop end)

        do_mutate(
          %{deck | maindeck: deck.maindeck -- [possible]},
          opts,
          %{
            add: [Map.merge(pick, %{"count" => possible["count"]}) | add],
            drop: [possible | drop]
          },
          count - 1
        )

      _ ->
        do_mutate(deck, opts, acc, count)
    end
  end
end
