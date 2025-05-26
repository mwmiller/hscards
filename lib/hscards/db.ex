defmodule HSCards.DB do
  @moduledoc """
  Dealing with Hearthstone cards database
  """
  use GenServer
  require Logger

  # Client APIs

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    {:ok, db} = CubDB.start_link(data_dir: Path.join([:code.priv_dir(:hscards), "db"]))
    Logger.info("HSCards.DB started")
    {:ok, %{db: db}}
  end

  def get(dbf_id) do
    GenServer.call(__MODULE__, {:get, dbf_id})
  end

  def network_update do
    GenServer.cast(__MODULE__, :network_update)
  end

  # Server callbacks
  def handle_call({:get, dbf_id}, _from, state) do
    case CubDB.get(state.db, dbf_id) do
      nil -> {:reply, {:error, "Card not found dbfID: #{dbf_id}"}, state}
      card -> {:reply, {:ok, card}, state}
    end
  end

  @cards_endpoint "https://api.hearthstonejson.com/v1/latest/enUS/cards.json"
  def handle_cast(:network_update, state) do
    with {:ok, {{_, 200, _}, _headers, json}} <- :httpc.request(@cards_endpoint) do
      json
      |> to_string()
      |> :json.decode()
      |> Enum.map(fn card -> {card["dbfId"], card} end)
      |> then(fn cs -> CubDB.put_multi(state.db, cs) end)
    else
      err ->
        Logger.error("Failed to fetch cards: #{inspect(err)}")
    end

    {:noreply, state}
  end
end
