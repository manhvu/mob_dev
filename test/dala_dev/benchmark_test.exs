defmodule DalaDev.BenchmarkTest do
  use ExUnit.Case, async: false

  alias DalaDev.Benchmark

  describe "measure/3" do
    test "measures wall time" do
      {:ok, _result, stats} = Benchmark.measure(Node.self(), fn -> :timer.sleep(10) end)
      assert stats.wall_time > 0
    end
  end
end
