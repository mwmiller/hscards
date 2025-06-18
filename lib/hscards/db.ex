defmodule HSCards.DB do
  @moduledoc """
  Dealing with Hearthstone cards database
  """

  import Ecto.Query, only: [from: 2]
  require Logger

  def get_by_id(dbf_id) do
    HSCards.Repo.get_by(HSCard, dbfId: dbf_id)
  end

  @doc """
  Get a card by its name.
  Tries a direct match first, then falls back to a fuzzy search if no exact match is found.
  Returns `{:ok, card}` if found, `{:ambiguous, cards}` if multiple cards match,
  or `{:error, error_message}` if no matches are found.
  """
  def get_by_name(name) do
    case HSCards.Repo.all(
           from(c in HSCard,
             where: c.name == ^name,
             select: c.full_info
           )
         ) do
      [] -> get_by_name_fuzzy(name)
      [card] -> {:ok, card}
      cards -> {:ambiguous, cards}
    end
  end

  defp get_by_name_fuzzy(name) do
    like = "%#{name}%"

    case HSCards.Repo.all(
           from(c in HSCard,
             where: like(c.name, ^like),
             select: c.full_info
           )
         ) do
      [] -> {:error, "No cards found with name containing '#{name}'"}
      [card] -> {:ok, card}
      cards -> {:ambiguous, cards}
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
