defmodule HSCards.Constraints do
  @moduledoc """
  Deck building constraints reified
  """
  # String keys for less marshalling
  @constraints %{
    "ten different costs" => %{text_match: "10 cards of different Costs", constrained: "cost"},
    "least expensive minion" => %{text_match: "less than every minon", constrained: "cost"},
    "most expensive minion" => %{text_match: "more than every minion", constrained: "cost"},
    "no dupe" => %{text_match: "no duplicates", constrained: "count"},
    "no minon" => %{text_match: "deck has no minions", constrained: "type"},
    "no neutral" => %{text_match: "no Neutral cards", constrained: "cardClass"},
    "no two cost" => %{text_match: "no 2-Cost cards", constrined: "cost"},
    "no three cost" => %{text_match: "no 3-Cost cards", constrained: "cost"},
    "no four cost" => %{text_match: "no 4-Cost cards", constrained: "cost"},
    "only even" => %{text_match: "only even-Cost cards", constrained: "cost"},
    "only odd" => %{text_match: "only odd-Cost cards", constrained: "cost"},
    "same type" => %{text_match: "deck shares a minion type", constrained: "races"},
    "deck size" => %{text_match: "Your deck size", constrained: "count"},
    "none" => %{text_match: ""}
  }
  @keys @constraints
        |> Enum.reduce(MapSet.new(), fn
          {_, %{constrained: c}}, a -> MapSet.put(a, c)
          {_, _}, a -> a
        end)
        |> MapSet.to_list()

  @doc """
  List all known constraint types
  """

  def known, do: Map.keys(@constraints)

  @doc """
  List all keys constrained by known types
  """
  def keys, do: @keys

  def for_card_text(card)

  def for_card_text(t) when is_binary(t) do
    # Should only be one
    {constraint, _} =
      Enum.find(@constraints, fn {_, %{text_match: tm}} -> String.contains?(t, tm) end)

    constraint
  end

  def for_card_text(_), do: :none
end
