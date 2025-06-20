defmodule HSCards.DB do
  @moduledoc """
  Dealing with Hearthstone cards database
  """

  import Ecto.Query, only: [from: 2]
  require Logger

  @default_options [match: :both, field: :name]
  @doc """
  Default search options for the `find/2` function.
  """
  def default_options, do: @default_options

  @doc """
  Available fields for searching cards.
  """
  @available_fields [:name, :dbfId, :flavor, :artist]
  def available_fields, do: @available_fields

  @doc """
  Available match modes for searching cards.
  """
  @available_match_modes [:exact, :fuzzy, :both]
  def available_match_modes, do: @available_match_modes

  @doc """
  Find cards by serch term.

  returns:
  - `{:ok, card}` - if a single card is found.
  - `{:ambiguous, cards}` - if multiple cards match.
  - `{:error, reason}` - if no cards match.

  ## Example

      iex> HSCards.DB.find(123456, match: :exact, field: :dbfId)
      {:error, "No match"}
  """

  def find(term, options \\ []) do
    options = search_options(options)

    with true <- options[:match] in @available_match_modes,
         true <- options[:field] in @available_fields do
      # Broken out here because I might want to add more options later
      # or validate them differently
      selected_queries =
        case options[:match] do
          :exact -> [exact_query(term, options[:field])]
          :fuzzy -> [fuzzy_query(term, options[:field])]
          :both -> [exact_query(term, options[:field]), fuzzy_query(term, options[:field])]
        end

      search_queries(selected_queries)
    else
      _ ->
        {:error,
         "Invalid search options. Available match modes: #{inspect(@available_match_modes)}, available fields: #{inspect(@available_fields)}"}
    end
  end

  defp search_options(options) do
    Keyword.merge(@default_options, options)
  end

  defp exact_query(term, which) do
    from(c in HSCards.Card,
      where: field(c, ^which) == ^term,
      select: c.full_info
    )
  end

  defp fuzzy_query(term, which) do
    like = "%#{term}%"

    from(c in HSCards.Card,
      where: like(field(c, ^which), ^like),
      select: c.full_info
    )
  end

  defp search_queries([]), do: {:error, "No match"}

  defp search_queries([query | rest]) do
    case HSCards.Repo.all(query) do
      [] -> search_queries(rest)
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
