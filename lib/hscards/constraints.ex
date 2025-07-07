defmodule HSCards.Constraints do
  @moduledoc """
  Deck building constraints reified
  """
  # String keys for less marshalling
  # This associates with the functions, we'll see if we can find a way to combine
  @constraints %{
    "ten different costs" => %{text_match: "10 cards of different Costs", constrained: "cost"},
    "least expensive minion" => %{
      text_match: "less than every minon",
      constrained: ["cost", "type"]
    },
    "most expensive minion" => %{
      text_match: "more than every minion",
      constrained: ["cost", "type"]
    },
    "no dupe" => %{text_match: "no duplicates", constrained: "count"},
    "no minion" => %{text_match: "deck has no minions", constrained: "type"},
    "no neutral" => %{text_match: "no Neutral cards", constrained: "cardClass"},
    "no two cost" => %{text_match: "no 2-Cost cards", constrained: "cost"},
    "no three cost" => %{text_match: "no 3-Cost cards", constrained: "cost"},
    "no four cost" => %{text_match: "no 4-Cost cards", constrained: "cost"},
    "only even" => %{text_match: "only even-Cost cards", constrained: "cost"},
    "only odd" => %{text_match: "only odd-Cost cards", constrained: "cost"},
    "same type" => %{text_match: "deck shares a minion type", constrained: ["races", "type"]},
    "deck size forty" => %{
      text_match: "Your deck size and starting Health are 40.",
      constrained: "count"
    },
    "none" => %{constrained: "constraint"}
  }
  @keys @constraints
        |> Enum.reduce(MapSet.new(), fn {_, %{constrained: c}}, a -> MapSet.put(a, c) end)
        |> MapSet.to_list()

  @doc """
  List all known constraint types
  """

  def known, do: Map.keys(@constraints)

  @doc """
  List all keys constrained by known types
  """
  def keys, do: @keys

  @doc """
  Emit constraint for given card text
  """
  def for_card_text(card_text)

  def for_card_text(t) when is_binary(t) do
    # Should only be one
    case Enum.find(@constraints, fn
           {_, %{text_match: tm}} -> String.contains?(t, tm)
           _ -> false
         end) do
      nil -> "none"
      {constraint, _meta} -> constraint
    end
  end

  def for_card_text(_), do: :none

  def verify(deck_info)

  def verify(%{"constraint" => cons} = di) do
    bad =
      cons
      |> Enum.reduce([], fn c, a -> [verify_constraint(c, di) | a] end)
      |> Enum.reject(fn v -> v == :valid end)

    case bad do
      [] -> :valid
      broken -> {:invalid, broken}
    end
  end

  def verify(_) do
    :valid
  end

  defp verify_constraint(constraint_key_value_tuple, deck_info)
  defp verify_constraint({"none", _}, _), do: :valid

  defp verify_constraint({"deck size forty", from}, %{"count" => c}) do
    case Enum.reduce(c, 0, fn {count, cards}, a -> a + count * length(cards) end) do
      40 ->
        :valid

      n ->
        constraint_invalid("deck size forty", from, "Deck size of #{n}")
    end
  end

  defp verify_constraint({"no dupe", from}, %{"count" => c}) do
    case Enum.filter(c, fn {k, _v} -> k != 1 end) do
      [] ->
        :valid

      broken ->
        constraint_invalid("no dupe", from, broken)
    end
  end

  defp verify_constraint({"only odd", from}, %{"cost" => c}) do
    case Enum.filter(c, fn {k, _v} -> rem(k, 2) == 0 end) do
      [] ->
        :valid

      broken ->
        constraint_invalid("only odd", from, broken)
    end
  end

  defp verify_constraint({"only even", from}, %{"cost" => c}) do
    case Enum.filter(c, fn {k, _v} -> rem(k, 2) == 1 end) do
      [] ->
        :valid

      broken ->
        constraint_invalid("only odd", from, broken)
    end
  end

  defp verify_constraint({"no minion", from}, %{"type" => t}) do
    case Map.get(t, "MINION", []) do
      [] ->
        :valid

      broken ->
        constraint_invalid("no minion", from, broken)
    end
  end

  defp verify_constraint({"no neutral", from}, %{"cardClass" => c}) do
    case Map.get(c, "NEUTRAL", []) do
      [] ->
        :valid

      broken ->
        constraint_invalid("no neutral", from, broken)
    end
  end

  defp constraint_invalid(constraint, from, by) do
    [
      constraint: constraint,
      from: dbfs_to_card_list(from),
      by:
        case by do
          s when is_binary(s) ->
            [s]

          l when is_list(l) ->
            Enum.reduce(l, %{}, fn {k, v}, a -> Map.put(a, k, dbfs_to_card_list(v)) end)
        end
    ]
  end

  defp dbfs_to_card_list(dbfs) do
    Enum.map(dbfs, fn dbfId ->
      {:ok, c} = HSCards.by_dbf(dbfId)
      c
    end)
  end
end
