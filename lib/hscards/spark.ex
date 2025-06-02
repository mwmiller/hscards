defmodule HSCards.Spark do
  @moduledoc """
  Spark module for HSCards.
  """
  @height {" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"}

  @doc """
  Generates a sparkline for a given list of values.
  """
  def plot(values) when is_tuple(values) do
    values
    |> Tuple.to_list()
    |> plot()
  end

  def plot(values) when is_list(values) do
    do_plot(Enum.filter(values, fn e -> is_number(e) end))
  end

  def plot(_), do: {:error, "plot data should be in a list or tuple"}

  defp do_plot(vals) when length(vals) > 2 and length(vals) < 21 do
    plot =
      case {Enum.max(vals), Enum.min(vals)} do
        {m, m} ->
          String.duplicate(elem(@height, 4), length(vals))

        {max, min} ->
          vals
          |> Enum.map(fn
            0 -> elem(@height, 0)
            v -> elem(@height, max(1, round((v - min) / (max - min) * 8)))
          end)
          |> Enum.join()
      end

    {:ok, plot}
  end

  defp do_plot(_), do: {:error, "plot data should have between 3 and 20 numbers."}
end
