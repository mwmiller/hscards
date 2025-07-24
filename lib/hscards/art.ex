defmodule HSCards.Art do
  # There is more than one way to get the full art URL for a card, even
  # ignoring localization.
  # We're going to focus on what works for us and let the rest sort itself out.
  require Logger
  @styles ["tiles", "256x"]
  @base_url "https://art.hearthstonejson.com/v1"
  @base_dir :code.priv_dir(:hscards) |> Path.join("images")

  @doc """
  Available art styles.
  """
  def styles, do: @styles

  @doc """
  Fill out the images for a given deck
  """
  def fill_deck_images(deck)

  def fill_deck_images(deck) when is_binary(deck) do
    deck
    |> HSCards.from_deckstring()
    |> fill_deck_images()
  end

  def fill_deck_images(deck) do
    add_key_images([:maindeck, :sideboard, :heroes], deck)
  end

  defp add_key_images([], deck), do: deck

  defp add_key_images([key | rest], deck) do
    add_key_images(rest, Map.update!(deck, key, fn klist -> add_images(klist) end))
  end

  defp add_images(cards, acc \\ [])
  defp add_images([], acc), do: acc

  defp add_images([card | rest], acc) do
    add_images(rest, [
      Map.put(card, "images", %{
        "tiles" => by_card(card, "tiles"),
        "256x" => by_card(card, "256x")
      })
      | acc
    ])
  end

  def by_card(card, style \\ "tiles")

  def by_card(card, style) when style in @styles do
    case card do
      %{"id" => id} when is_binary(id) -> file_by_id(id, style)
      id when is_binary(id) -> file_by_id(id, style)
      _ -> file_by_id("default", style)
    end
  end

  def by_card(_, style) do
    raise ArgumentError,
          "Invalid style: #{style}. Available styles are: #{Enum.join(@styles, ", ")}"
  end

  defp path(id, style, where \\ @base_dir), do: where <> "/#{style}/#{id}.jpg"

  defp file_by_id(id, style) do
    case File.read(path(id, style)) do
      {:ok, contents} ->
        contents

      {:error, :enoent} ->
        # If the file doesn't exist, we can try to fetch it from the web.
        Task.start(fn ->
          load_art(id, style)
        end)

        file_by_id("default", style)
    end
  end

  defp load_art(id, style) do
    with {:ok, {{_, 200, _}, _headers, img_data}} <-
           :httpc.request(path(id, style, @base_url)) do
      file_path = path(id, style)

      # Ensure the directory exists
      File.mkdir_p!(Path.dirname(file_path))

      # Write the file to disk
      case File.write(file_path, img_data) do
        :ok -> Logger.info("Art file #{file_path} written successfully.")
        {:error, reason} -> Logger.warning("Failed to write art file #{file_path}: #{reason}")
      end
    else
      {:ok, {{_, status_code, _}, _headers, _}} ->
        Logger.warning("Failed to fetch art for #{id} in style #{style}: HTTP #{status_code}")

      {:error, reason} ->
        Logger.warning("Failed to fetch art for #{id} in style #{style}: #{reason}")
    end
  end
end
