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
            set_ms = sets |> Enum.map(fn s -> s.code end) |> MapSet.new()

            %{
              year: String.to_integer(year),
              code: String.upcase(animal),
              name: "Year of the #{animal}",
              sets: sets,
              set_ms: set_ms,
              begins: foty.release_date,
              ends: ends
            }
          end)
          |> Enum.sort_by(& &1.begins, {:asc, Date})

  @doc """
  Infer the year for a standard deck from its composition.
  As a convenience will convert a supplied deckstring if possible

  Returns: `{:ok, zodiacyear_string]` or `{:error, msg}`
  """
  def zodiac_from_deck(deck)

  def zodiac_from_deck(deck) when is_binary(deck) do
    deck |> HSCards.from_deckstring() |> zodiac_from_deck
  end

  # This is the super-naive solution
  # We might want to build better structures and run in reverse
  def zodiac_from_deck(%{format: :standard} = deck) do
    (deck.maindeck ++ deck.sideboard)
    |> Enum.map(fn card -> Map.get(card, "set", "INVALID") end)
    |> MapSet.new()
    |> match_set(@zodiac)
  end

  def zodiac_from_deck(_), do: {:error, "Must supply a valid standard deck to determine year"}

  defp match_set(_, []), do: {:error, "Cannot find a matching zodiac year"}

  defp match_set(used, [zodiac | rest]) do
    # Will fix up precomputation when I settle everything
    precomputed = zodiac.set_ms

    year_sets =
      case MapSet.member?(precomputed, "CORE_#{zodiac.year}") do
        true -> MapSet.put(precomputed, "CORE")
        false -> precomputed
      end

    diff = MapSet.difference(used, year_sets)

    case MapSet.size(diff) do
      0 -> {:ok, zodiac.name}
      _ -> match_set(used, rest)
    end
  end
end
