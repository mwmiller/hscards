defmodule HSCards.DB do
  @moduledoc """
  Dealing with Hearthstone cards database
  """

  require Logger

  def get_by_id(dbf_id) do
    HSCards.Repo.get_by(HSCard, dbfId: dbf_id)
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
