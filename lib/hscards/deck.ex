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

    {errors, _} =
      deck.maindeck
      |> Enum.reduce(MapSet.new(), fn c, a -> MapSet.put(a, c["dbfId"]) end)
      |> included_constraints()
      |> validate_counts(proper.maindeck)
      |> validate_counts(Map.get(proper, :sideboard, []))
      |> validate_size(proper)
      |> validate_zodiac(proper)
      |> validate_cost(proper.maindeck)

    case map_size(errors) do
      0 -> {:valid, proper}
      _ -> {:invalid, errors}
    end
  end

  defp included_constraints(included) do
    {constraints, _} =
      {%{}, included}
      |> count_constraints
      |> size_constraints
      |> cost_constraints

    {%{}, constraints}
  end

  defp validate_zodiac(acc, %{format: :wild}), do: acc

  defp validate_zodiac({acc, constraints}, deck) do
    # If we stuck in the zodiac key then we already did the check
    case Map.get(deck, :zodiac) do
      nil -> {Map.put(acc, :non_standard_sets, deck.sets), constraints}
      _ -> {acc, constraints}
    end
  end

  defp validate_cost(pass, []), do: pass

  defp validate_cost({acc, %{cost: cfn} = cons}, [card | rest]) do
    na =
      case cfn.(card) do
        :ok -> acc
        list -> Map.update(acc, :bad_cost, list, fn a -> a ++ list end)
      end

    validate_cost({na, cons}, rest)
  end

  defp cost_constraints({acc, included}) do
    # These are only different versionof Renathal at present but I am
    # Making it flexible for later
    {ccc, ccms} =
      HSCards.DB.find(%{text: "Cost cards", collectible: true})
      |> then(fn {:ambiguous, cards} -> cards end)
      |> Enum.reduce({%{}, MapSet.new()}, fn c, {m, s} ->
        dbf = c["dbfId"]
        {Map.put(m, dbf, c), MapSet.put(s, dbf)}
      end)

    our_map =
      case MapSet.intersection(ccms, included) |> MapSet.to_list() do
        [] -> %{cost: fn _ -> :ok end}
        list -> %{cost: cost_fn(list, ccc)}
      end

    {Map.merge(acc, our_map), included}
  end

  defp cost_fn(dbfs, ccc, conds \\ %{})

  defp cost_fn([], _, conds) do
    fns =
      Enum.reduce(conds, [], fn
        {:odd, cards}, a -> [fn cost -> if rem(cost, 2) == 0, do: cards, else: :ok end | a]
        {:even, cards}, a -> [fn cost -> if rem(cost, 2) == 1, do: cards, else: :ok end | a]
        {num, cards}, a -> [fn cost -> if cost == num, do: cards, else: :ok end | a]
      end)

    fn c ->
      Enum.reduce(fns, [], fn f, a ->
        case f.(Map.get(c, "cost", -1)) do
          :ok -> a
          cards -> [{c, cards} | a]
        end
      end)
    end
  end

  defp cost_fn([dbf | rest], ccc, conds) do
    ocard = ccc[dbf]
    oct = ocard["text"]

    # Only one of these should match, but we do them individually for reasons
    c0 =
      case Regex.named_captures(~r/only (?<parity>odd|even)/, oct) do
        %{"parity" => p} -> Map.update(conds, String.to_atom(p), [ocard], fn a -> [ocard | a] end)
        _ -> conds
      end

    c1 =
      case Regex.named_captures(~r/no (?<num>\d+)/, oct) do
        %{"num" => n} -> Map.update(c0, String.to_integer(n), [ocard], fn a -> [ocard | a] end)
        _ -> c0
      end

    cost_fn(rest, ccc, c1)
  end

  defp validate_size({acc, %{size: size, size_constraint: why} = cons}, deck) do
    case size(deck) do
      %{maindeck: ^size} ->
        {acc, cons}

      sizing ->
        {Map.merge(acc, %{improper_size: sizing, size_constraint: why}), cons}
    end
  end

  defp size_constraints({acc, included}) do
    # These are only different versionof Renathal at present but I am
    # Making it flexible for later
    {dsc, dsms} =
      HSCards.DB.find(%{text: "deck size", collectible: true})
      |> then(fn {:ambiguous, cards} -> cards end)
      |> Enum.reduce({%{}, MapSet.new()}, fn c, {m, s} ->
        dbf = c["dbfId"]
        {Map.put(m, dbf, c), MapSet.put(s, dbf)}
      end)

    our_map =
      case MapSet.intersection(dsms, included) |> MapSet.to_list() do
        [] ->
          %{size: 30, size_constraint: []}

        [adjust] ->
          card = dsc[adjust]

          # This probably needs more consideration later
          case Regex.named_captures(~r/(?<count>\d+)/, card["text"]) do
            %{"count" => c} -> %{size: String.to_integer(c), size_constraint: [card]}
            _ -> %{size: 30, size_constraint: [card]}
          end
      end

    {Map.merge(acc, our_map), included}
  end

  defp validate_counts(acc, []), do: acc

  defp validate_counts(acc, [%{"count" => 1, "rarity" => "LEGENDARY"} | rest]),
    do: validate_counts(acc, rest)

  defp validate_counts({_, %{max_count: mc}} = acc, [%{"count" => c, "rarity" => r} | rest])
       when r != "LEGENDARY" and c <= mc do
    validate_counts(acc, rest)
  end

  defp validate_counts({acc, %{count_constraint: cc} = cons}, [card | rest]) do
    acc
    |> Map.put(:count_constraint, cc)
    |> Map.update(:improper_count, [card], fn a -> [card | a] end)
    |> then(fn a -> validate_counts({a, cons}, rest) end)
  end

  defp count_constraints({acc, included}) do
    {hlc, hlms} =
      HSCards.DB.find(%{text: "no duplicates", collectible: true})
      |> then(fn {:ambiguous, cards} -> cards end)
      |> Enum.reduce({%{}, MapSet.new()}, fn c, {m, s} ->
        dbf = c["dbfId"]
        {Map.put(m, dbf, c), MapSet.put(s, dbf)}
      end)

    our_map =
      case MapSet.intersection(hlms, included) |> MapSet.to_list() do
        [] -> %{max_count: 2, count_constraint: []}
        list -> %{max_count: 1, count_constraint: Enum.map(list, fn id -> hlc[id] end)}
      end

    {Map.merge(acc, our_map), included}
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
