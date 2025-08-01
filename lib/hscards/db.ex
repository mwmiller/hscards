defmodule HSCards.DB do
  @moduledoc """
  Dealing with Hearthstone cards database
  """

  import Ecto.Query
  require Logger
  alias HSCards.{Evaluate, Learned, Images}

  @default_options [string_match: :fuzzy, query_mode: :and]
  @doc """
  Default search options for the `find/2` function.
  """
  def default_options, do: @default_options

  @available_fields [
    :name,
    :dbfId,
    :flavor,
    :artist,
    :mechanic,
    :class,
    :cost,
    :collectible,
    :rarity,
    :text,
    :set,
    :constraint
  ]
  @doc """
  Available fields for searching cards.
  """
  def available_fields, do: @available_fields

  @available_string_matches [:exact, :fuzzy]
  @doc """
  Available match modes for searching cards.
  """
  def available_string_matches, do: @available_string_matches

  @available_query_modes [:and, :or]
  @doc """
  Available query modes for searching cards.
  """
  def available_query_modes, do: @available_query_modes

  @doc """
  Find cards by search map.

  Search map should use atom keys from `available_fields/0`
  Values should be single values (list support coming soon!)

  Query mode selects between the union and intersection of the resulting
  card sets.

  Field match chooses between substring and exact matches.

  returns:
  - `{:ok, card}` - if a single card is found.
  - `{:ambiguous, cards}` - if multiple cards match.
  - `{:error, reason}` - if no cards match.

  ## Example

      iex> HSCards.DB.find(%{dbfId: 123456}, string_match: :exact, query_mode: :and)
      {:error, "No match"}
  """

  def find(terms_map, options \\ []) do
    # We do all of the validation here to avoid propogating errors later
    options = search_options(options)

    with true <- options[:string_match] in @available_string_matches,
         true <- options[:query_mode] in @available_query_modes,
         [] <-
           Enum.reject(Map.keys(terms_map), fn k -> k in @available_fields end) do
      search_queries(terms_map, options)
    else
      false ->
        {:error,
         "Invalid search options. Available string match modes: #{inspect(@available_string_matches)}, available query modes: #{inspect(@available_query_modes)}"}

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
    # We always or on the fields, but we use the query mode to combine
    # the results of the individual field queries
    nq =
      case options[:query_mode] do
        :and ->
          query
          |> where(^terms_clause(term, field, options[:string_match], false))

        :or ->
          query
          |> or_where(^terms_clause(term, field, options[:string_match], false))
      end

    field_queries(rest, options, nq)
  end

  # This is kind of a goofy shared functon head.
  defp terms_clause(term, field, match_type, prev) when not is_list(term) do
    # We don't mind that we OR in a `false` here, it just makes the
    # dynamic clause more readable

    # If the term is an integer or booleans, we force an exact match
    # This isn't exactly the same as checking the field type
    # but it is close enough for our purposes
    case is_binary(term) and match_type == :fuzzy do
      true ->
        like_term = "%#{term}%"
        dynamic([c], like(field(c, ^field), ^like_term) or ^prev)

      false ->
        dynamic([c], field(c, ^field) == ^term or ^prev)
    end
  end

  # This is the case where we have a list of terms
  defp terms_clause([], _field, _options, clause), do: clause

  defp terms_clause([term | rest], field, options, clause) do
    terms_clause(rest, field, options, terms_clause(term, field, options, clause))
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
    Updates the various database sources.
  """
  def update_from_sources() do
    Logger.info("Updating database from sources")

    with {:ok, {{_, 200, _}, _headers, json}} <- :httpc.request(@cards_endpoint) do
      Logger.info("Fetched cards from #{@cards_endpoint}")

      json
      |> Evaluate.json_to_entries()
      |> Enum.chunk_every(2048)
      |> Enum.each(fn chunk ->
        HSCards.Repo.insert_all(HSCards.Card, chunk, on_conflict: :replace_all)
      end)

      Logger.info("Inserted cards into the database")
    else
      err ->
        Logger.error("Failed to fetch cards: #{inspect(err)}")
        :error
    end

    # Someday this will move to more configurability
    which = %{collectible: true}

    cards =
      case HSCards.DB.find(which) do
        {:ok, card} -> [card]
        {:ambiguous, cards} -> cards
        _ -> []
      end

    Logger.info("Preparing to update #{inspect(which)} cards embeddings and art...")

    Learned.update_embeddings(cards)

    Images.update_from_sources(cards)

    # Above purely for side-effects. :(
    :ok
  end
end
