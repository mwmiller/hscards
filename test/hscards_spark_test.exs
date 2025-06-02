defmodule HSCardsSparkTest do
  use ExUnit.Case
  doctest HSCards.Spark
  alias HSCards.Spark

  test "example plots" do
    assert {:ok, " ▄█"} == Spark.plot([0, 1, 2])
    assert {:ok, " ▄█"} == Spark.plot([:something, 0, 1, 2, "extraneous"])
    assert {:ok, " ▄█"} == Spark.plot({0, 1, 2})
    assert {:ok, " ▃▅█"} == Spark.plot({0, 1, 2, 3})
    assert {:ok, " ▁▁▁█"} == Spark.plot({0, 1, 2, 3, 20})
    assert {:ok, "▁▄█▄▁"} == Spark.plot({1, 2, 3, 2, 1})
    assert {:ok, "▁▁▂▃▅▆▇█▇▆▅▃▂▁▁"} == Spark.plot({1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1})

    assert {:ok, "▁▂▁▄ ▆ █▁▆▁▄▁▂▁"} ==
             Spark.plot([1, 20, 3, 40, 0, 60, 0, 80, 7, 60, 5, 40, 3, 20, 1])

    assert {:ok, "▄▄▄▄▄▄▄▄▄▄"} == Spark.plot(Tuple.duplicate(10, 10))
  end

  test "error conditions" do
    assert {:error, "plot data should have between 3 and 20 numbers."} == Spark.plot([])
    assert {:error, "plot data should have between 3 and 20 numbers."} == Spark.plot({0, 0})
    assert {:error, "plot data should be in a list or tuple"} == Spark.plot("01234")

    assert {:error, "plot data should have between 3 and 20 numbers."} ==
             Spark.plot({:something, 0, 1, "extraneous"})

    assert {:error, "plot data should have between 3 and 20 numbers."} ==
             Spark.plot(Tuple.duplicate(10, 100))
  end
end
