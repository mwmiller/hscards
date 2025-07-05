defmodule HSCards.Evaluate do
  @moduledoc """
  This used to be dynamic, but it got messy.
  """

  @doc """
  Convert raw json into  entries for Ecto
  """
  def json_to_entries(json) do
    json
    |> to_string
    |> :json.decode()
    |> Enum.reduce([], fn card, acc ->
      [
        [
          dbfId: card["dbfId"],
          name: card["name"],
          rarity: card["rarity"],
          set: card["set"],
          text: normalize_text(card["text"]),
          collectible: boolean(card["collectible"]),
          cost: card["cost"],
          class: index_classes(card),
          mechanic: array_to_index_string(card["mechanics"]),
          artist: not_null(card["artist"]),
          flavor: not_null(card["flavor"]),
          full_info: card
        ]
        | acc
      ]
    end)
  end

  defp boolean(true), do: true
  defp boolean(_), do: false

  defp not_null(nil), do: ""
  defp not_null(value), do: value

  defp normalize_text(text) when is_binary(text) do
    text
    |> String.replace("-\n", "-")
    |> String.replace(["\u00A0", "\u{c2}", "\n"], " ")
    |> String.replace(~r/\s+/, " ")
  end

  defp normalize_text(_), do: ""
  # Extract class data from the downloaded card data.
  # If it has classes set, use that, otherwise use cardClass.
  # some other modes don't have this, but I don't care about those
  defp index_classes(%{"classes" => classes}) do
    array_to_index_string(classes)
  end

  defp index_classes(%{"cardClass" => cc}) do
    cc
  end

  defp index_classes(_), do: ""

  # We need something againt which we can do string comparisons
  # We never return this so it can use this unprntable format
  defp array_to_index_string(array) when is_list(array) do
    Enum.join(array, <<2>>)
  end

  defp array_to_index_string(_), do: ""
end
