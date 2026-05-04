defmodule MobDev.ErrorTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "creates simple error tuple" do
      assert {:error, "something went wrong"} = MobDev.Error.new("something went wrong")
    end
  end

  describe "new/2" do
    test "creates error tuple with module context" do
      assert {:error, :my_module, "reason"} = MobDev.Error.new(:my_module, "reason")
    end
  end

  describe "format/1" do
    test "formats simple error" do
      assert "something went wrong" = MobDev.Error.format({:error, "something went wrong"})
    end

    test "formats error with module context" do
      result = MobDev.Error.format({:error, :my_module, "reason"})
      assert String.contains?(result, ":my_module")
      assert String.contains?(result, "reason")
    end

    test "formats atom reason" do
      assert "noproc" = MobDev.Error.format({:error, :noproc})
    end

    test "formats complex reason" do
      reason = {:badmatch, 42}
      formatted = MobDev.Error.format({:error, reason})
      assert is_binary(formatted)
    end
  end

  describe "wrap/2" do
    test "returns ok tuple on success" do
      assert {:ok, 42} = MobDev.Error.wrap(:context, fn -> {:ok, 42} end)
    end

    test "returns error tuple on failure" do
      result = MobDev.Error.wrap(:context, fn -> {:error, "failed"} end)
      assert {:error, _} = result
    end

    test "catches exceptions" do
      result = MobDev.Error.wrap(:my_context, fn -> raise "boom" end)
      assert {:error, {:my_context, _}} = result
    end
  end
end
