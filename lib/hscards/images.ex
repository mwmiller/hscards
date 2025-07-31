defmodule HSCards.Images do
  # There is more than one way to get the full art URL for a card, even
  # ignoring localization.
  # We're going to focus on what works for us and let the rest sort itself out.
  require Logger

  @styles %{
    tile: %{
      web_folder: "tiles",
      default:
        [:code.priv_dir(:hscards), "default-tile.jpg"]
        |> Path.join()
        |> File.read!()
        |> then(fn d -> "data:image/jpeg;base64," <> Base.encode64(d) end)
    },
    full: %{
      web_folder: "256x",
      default:
        [:code.priv_dir(:hscards), "default-full.jpg"]
        |> Path.join()
        |> File.read!()
        |> then(fn d -> "data:image/jpeg;base64," <> Base.encode64(d) end)
    }
  }

  @default_art @styles
               |> Map.keys()
               |> Enum.reduce(%{}, fn k, acc ->
                 Map.put(acc, Atom.to_string(k), @styles[k].default)
               end)
  @base_url "https://art.hearthstonejson.com/v1"

  @doc """
  Fill out the images for a given deck
  """
  def fill_deck(deck)

  def fill_deck(deck) when is_binary(deck) do
    deck
    |> HSCards.from_deckstring()
    |> fill_deck()
  end

  def fill_deck(deck) do
    add_key([:maindeck, :sideboard, :heroes], deck)
  end

  defp add_key([], deck), do: deck

  defp add_key([key | rest], deck) do
    add_key(rest, Map.update!(deck, key, fn klist -> add(klist) end))
  end

  defp add(cards, acc \\ [])

  defp add([card | rest], acc) do
    add(rest, [Map.put(card, :art, by_card(card)) | acc])
  end

  @doc """
  Get the art for a card in a specific style.
  If the card is not found, it will return the default art.
  If the art is not found, it will attempt to fetch it from the web,
  to be available on the next request.
  """
  def by_card(card) do
    case card do
      %{"id" => id} when is_binary(id) ->
        by_id(id)

      id when is_binary(id) ->
        by_id(id)

      _ ->
        Logger.error("Invalid card format for art load: #{inspect(card)}")
        @default_art
    end
  end

  defp web_path(id, style) do
    %{web_folder: f} = Map.get(@styles, style, %{})
    @base_url <> "/#{f}/#{id}.jpg"
  end

  defp by_id(id) do
    case HSCards.Repo.get_by(HSCards.Art, hs_id: id) do
      %HSCards.Art{full: full, tile: tile} when not is_nil(full) and not is_nil(tile) ->
        %{"tile" => tile, "full" => full}

      _ ->
        Logger.info("Art not found for card #{id}, fetching from web")
        Task.start(fn -> load_art(id) end)
        @default_art
    end
  end

  def update_from_sources(todo) do
    Logger.info("Refreshing images: #{length(todo)} cards to process")

    # Broadway or even GenStage seems like overkill for this
    todo
    |> Enum.shuffle()
    |> Enum.chunk_every(128)
    |> Enum.reduce(0, fn chunk, a ->
      Process.sleep(503)

      chunk
      |> Enum.map(fn c -> c["id"] end)
      |> load_art([])

      # Avoid overwhelming the server
      total = a + length(chunk)
      Logger.info("Processed #{length(chunk)} cards, total processed: #{total}")
      total
    end)

    Logger.info("Image refresh complete")
  end

  defp load_art(id) when is_binary(id) do
    load_art([id], [])
  end

  defp load_art([], acc) do
    HSCards.Repo.insert_all(HSCards.Art, acc, on_conflict: :replace_all)
  end

  defp load_art([id | rest], acc) do
    qable =
      @styles
      |> Map.keys()
      |> Enum.reduce([hs_id: id], fn style, a -> [{style, fetch_art(id, style)} | a] end)

    load_art(rest, [qable | acc])
  end

  defp data_uri(data) do
    ["data:image/jpeg;base64," | data]
    |> IO.iodata_to_binary()
  end

  defp fetch_art(id, style) do
    with {:ok, {{_, 200, _}, _headers, img_data}} <-
           :httpc.request(web_path(id, style)) do
      data_uri(img_data)
    else
      _ ->
        nil
    end
  end
end
