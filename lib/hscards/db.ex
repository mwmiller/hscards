defmodule HSCards.DB do
  @moduledoc """
  Dealing with Hearthstone cards database
  """

  import Ecto.Query, only: [from: 2]
  require Logger

  @doc """
  Find cards by serch term.
  Keyword Options:
  - `field:` (`:name` default)- which field to match against.
    Available fields:
      - `:name` - the name of the card.
      - `:dbfId` - the unique identifier for the card.
  - `match:` - how to match the name.
    Available match modes:
      - `:exact` - return cards with an exact match.
      - `:fuzzy` - return cards with a substring match.
      - `:both` (default) - returns `:exact` match if found, otherwise falls back to `:fuzzy`.

  returns:
  - `{:ok, card}` - if a single card is found.
  - `{:ambiguous, cards}` - if multiple cards match.
  - `{:error, reason}` - if no cards match.
  """
  @default_options [match: :both, field: :name]
  @available_fields [:name, :dbfId]
  @available_match_modes [:exact, :fuzzy, :both]

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
         "Invalid search options. Available match modes: #{@available_match_modes}, available fields: #{@available_fields}"}
    end
  end

  defp search_options(options) do
    Keyword.merge(@default_options, options)
  end

  defp exact_query(term, which) do
    from(c in HSCard,
      where: field(c, ^which) == ^term,
      select: c.full_info
    )
  end

  defp fuzzy_query(term, which) do
    like = "%#{term}%"

    from(c in HSCard,
      where: like(field(c, ^which), ^like),
      select: c.full_info
    )
  end

  defp search_queries([]), do: {:error, "No matching cards found"}

  defp search_queries([query | rest]) do
    case HSCards.Repo.all(query) do
      [] -> search_queries(rest)
      [card] -> {:ok, card}
      cards when length(cards) > 1 -> {:ambiguous, cards}
    end
  end

  @cards_endpoint "https://api.hearthstonejson.com/v1/latest/enUS/cards.json"
  def update_from_sources do
    with {:ok, {{_, 200, _}, _headers, json}} <- :httpc.request(@cards_endpoint) do
      json
      |> to_string()
      |> :json.decode()
      |> Enum.map(fn card -> {card["dbfId"], card["name"], card} end)
      |> Enum.each(fn {dbf_id, name, card} ->
        HSCards.Repo.insert(
          %HSCard{
            dbfId: dbf_id,
            name: name,
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
