defmodule HSCards.DB do
  @moduledoc """
  Dealing with Hearthstone cards database
  """

  import Ecto.Query
  require Logger

  @default_options [field_match: :fuzzy, query_mode: :and]
  @doc """
  Default search options for the `find/2` function.
  """
  def default_options, do: @default_options

  @available_fields [:name, :dbfId, :flavor, :artist]
  @doc """
  Available fields for searching cards.
  """
  def available_fields, do: @available_fields

  @available_field_matches [:exact, :fuzzy]
  @doc """
  Available match modes for searching cards.
  """
  def available_field_matches, do: @available_field_matches

  @available_query_modes [:and, :or]
  @doc """
  Available query modes for searching cards.
  """
  def available_query_modes, do: @available_query_modes

  @doc """
  Find cards by search map.

  Search map should use atom keys from `available_field_matches/0`
  Values should be single values (list support coming soon!)

  Query mode selects between the union and intersection of the resulting
  card sets.

  Field match chooses between substring and exact matches.

  returns:
  - `{:ok, card}` - if a single card is found.
  - `{:ambiguous, cards}` - if multiple cards match.
  - `{:error, reason}` - if no cards match.

  ## Example

      iex> HSCards.DB.find(%{dbfId: 123456}, field_match: :exact, query_mode: :and)
      {:error, "No match"}
  """

  def find(terms_map, options \\ []) do
    # We do all of the validation here to avoid propogating errors later
    options = search_options(options)

    with true <- options[:field_match] in @available_field_matches,
         true <- options[:query_mode] in @available_query_modes,
         [] <-
           Enum.reject(Map.keys(terms_map), fn k -> k in @available_fields end) do
      search_queries(terms_map, options)
    else
      false ->
        {:error,
         "Invalid search options. Available match modes: #{inspect(@available_field_matches)}, available query modes: #{inspect(@available_query_modes)}"}

      bad_fields ->
        {:error,
         "Invalid search fields. Available fields: #{inspect(@available_fields)}, but got: #{inspect(bad_fields)}"}
    end
  end

  defp search_options(options) do
    Keyword.merge(@default_options, options)
  end

  defp field_queries([], _options, query), do: query

  defp field_queries([{field, term} | rest], options, query) do
    nq =
      case options[:field_match] do
        :exact ->
          case options[:query_mode] do
            :and -> query |> where([c], field(c, ^field) == ^term)
            :or -> query |> or_where([c], field(c, ^field) == ^term)
          end

        :fuzzy ->
          like_term = "%#{term}%"

          case options[:query_mode] do
            :and -> query |> where([c], like(field(c, ^field), ^like_term))
            :or -> query |> or_where([c], like(field(c, ^field), ^like_term))
          end
      end

    field_queries(rest, options, nq)
  end

  defp search_queries(terms_map, options) do
    query =
      terms_map
      |> Map.to_list()
      |> field_queries(options, from(c in HSCards.Card, select: c.full_info))

    case HSCards.Repo.all(query) do
      [] -> {:error, "No match"}
      [card] -> {:ok, card}
      cards -> {:ambiguous, cards}
    end
  end

  @cards_endpoint "https://api.hearthstonejson.com/v1/latest/enUS/cards.json"
  @doc """
    Fetches the latest cards from the Hearthstone JSON API and updates the local database.
  """
  def update_from_sources do
    with {:ok, {{_, 200, _}, _headers, json}} <- :httpc.request(@cards_endpoint) do
      json
      |> to_string()
      |> :json.decode()
      |> Enum.each(fn card ->
        HSCards.Repo.insert(
          %HSCards.Card{
            dbfId: card["dbfId"],
            name: card["name"],
            artist: card["artist"],
            flavor: card["flavor"],
            full_info: card
          },
          on_conflict: :replace_all
        )
      end)

      Logger.info("Cards database updated successfully.")
      :ok
    else
      err ->
        Logger.error("Failed to fetch cards: #{inspect(err)}")
        :error
    end
  end
end
