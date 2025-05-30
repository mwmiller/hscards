defmodule HSCards.Spark do
  @moduledoc """
  Spark module for HSCards.
  """
  @height {"▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"}

  @doc """
  Generates a sparkline for a given list of values.
  """
  def plot(values) when is_tuple(values) do
    values
    |> Tuple.to_list()
    |> plot()
  end

  def plot(values) when is_list(values) do
    max = Enum.max(values)
    min = Enum.min(values)

    plot =
      values
      |> Enum.map(fn v -> elem(@height, round((v - min) / (max - min) * 7)) end)
      |> Enum.join()

    {:ok, plot}
  end

  def plot(_), do: {:error, "Input must be a list or tuple of numbers"}
end
