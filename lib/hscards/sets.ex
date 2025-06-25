defmodule HSCards.Sets do
  @moduledoc """
  Dealing with Hearthstone card sets.
  """

  @set_info :code.priv_dir(:hscards)
            |> Path.join("sets.tsv")
            |> File.read!()
            |> String.split("\n", trim: true)
            |> Enum.map(fn line ->
              [date, code, name] = String.split(line, "\t", trim: true)
              {:ok, rel} = Date.from_iso8601(date)
              %{release_date: rel, code: code, name: name}
            end)
            |> Enum.sort_by(& &1.release_date, {:asc, Date})

  @zodiac :code.priv_dir(:hscards)
          |> Path.join("zodiac.tsv")
          |> File.read!()
          |> String.split("\n", trim: true)
          |> Enum.map(fn line ->
            [year, animal] = String.split(line, "\t", trim: true)
            y = String.to_integer(year)

            [foty | roty] =
              Enum.filter(@set_info, fn set ->
                set.release_date.year == y
              end)

            prev =
              Enum.filter(@set_info, fn set ->
                set.release_date.year == y - 1 and not String.contains?(set.code, "CORE")
              end)

            ends =
              case Enum.find(@set_info, fn set -> set.release_date.year == y + 1 end) do
                nil -> ~D[9999-12-31]
                first -> first.release_date
              end

            sets = prev ++ [foty] ++ roty
            sets_ms = sets |> Enum.map(fn s -> s.code end) |> MapSet.new()

            %{
              year: String.to_integer(year),
              code: String.upcase(animal),
              name: "Year of the #{animal}",
              sets: sets,
              sets_ms: sets_ms,
              begins: foty.release_date,
              ends: ends
            }
          end)
          |> Enum.sort_by(& &1.begins, {:asc, Date})

  @doc """
  Collect set infomation about deck
  As a convenience will convert a supplied deckstring if possible

  Returns: `{:ok, zodiacyear_string]` or `{:error, msg}`
  """
  def add_deck_info(deck)

  def add_deck_info(deck) when is_binary(deck) do
    deck |> HSCards.from_deckstring() |> add_deck_info
  end

  # This is the super-naive solution
  # We might want to build better structures and run in reverse
  def add_deck_info(%{format: :standard} = deck) do
    deck_plus = add_basic_keys(deck)

    case match_zodiac(deck_plus.sets_ms, @zodiac) do
      {:ok, z} -> Map.merge(deck_plus, %{zodiac: z})
      _ -> deck_plus
    end
  end

  def add_deck_info(%{format: :wild} = deck) do
    add_basic_keys(deck)
  end

  def add_deck_info(_), do: {:error, "Must supply a valid standard or wild deck"}

  defp add_basic_keys(deck) do
    # We'll let that de-dupe for us
    ms =
      case Map.has_key?(deck, :sideboard) do
        true -> deck.maindeck ++ deck.sideboard
        false -> deck.maindeck
      end
      |> Enum.map(fn card -> Map.get(card, "set", "INVALID") end)
      |> MapSet.new()

    Map.merge(deck, %{sets: MapSet.to_list(ms), sets_ms: ms})
  end

  defp match_zodiac(_, []), do: {:error, "Cannot find a matching zodiac year"}

  defp match_zodiac(used, [zodiac | rest]) do
    # Will fix up precomputation when I settle everything
    precomputed = zodiac.sets_ms

    year_sets =
      case MapSet.member?(precomputed, "CORE_#{zodiac.year}") do
        true -> MapSet.put(precomputed, "CORE")
        false -> precomputed
      end

    diff = MapSet.difference(used, year_sets)

    case MapSet.size(diff) do
      0 -> {:ok, zodiac}
      _ -> match_zodiac(used, rest)
    end
  end
end
