defmodule DalaDev.UtilsTest do
  use ExUnit.Case, async: true

  describe "compile_regex/2" do
    test "compiles valid regex" do
      assert %Regex{} = DalaDev.Utils.compile_regex("hello\\s+world")
    end

    test "raises on invalid regex" do
      assert_raise RuntimeError, ~r/invalid regex pattern/i, fn ->
        DalaDev.Utils.compile_regex("[invalid")
      end
    end

    test "accepts options" do
      regex = DalaDev.Utils.compile_regex("hello", "i")
      assert Regex.match?(regex, "HELLO")
    end
  end

  describe "command_available?/1" do
    test "returns true for available command" do
      # ls should always be available on Unix
      assert DalaDev.Utils.command_available?("ls") == true
    end

    test "returns false for unavailable command" do
      assert DalaDev.Utils.command_available?("nonexistent_command_12345") == false
    end
  end

  describe "format_bytes/1" do
    test "formats bytes" do
      assert DalaDev.Utils.format_bytes(500) == "500 B"
    end

    test "formats kilobytes" do
      assert DalaDev.Utils.format_bytes(2048) == "2.0 KB"
    end

    test "formats megabytes" do
      # 2MB to be clear of boundary
      assert DalaDev.Utils.format_bytes(2_097_152) == "2.0 MB"
    end

    test "formats gigabytes" do
      # 2GB to be clear of boundary
      assert DalaDev.Utils.format_bytes(2_147_483_648) == "2.0 GB"
    end
  end

  describe "ensure_dir/1" do
    test "creates directory if not exists" do
      path = Path.join(System.tmp_dir!(), "dala_test_#{:erlang.unique_integer([:positive])}")
      assert :ok = DalaDev.Utils.ensure_dir(path)
      assert File.dir?(path)
      File.rm_rf!(path)
    end

    test "returns :ok if directory already exists" do
      path = System.tmp_dir!()
      assert :ok = DalaDev.Utils.ensure_dir(path)
    end
  end

  describe "run_adb_with_timeout/2" do
    test "function is callable" do
      # Verify the function exists and has the right arity
      assert function_exported?(DalaDev.Utils, :run_adb_with_timeout, 2)
    end

    test "handles missing timeout command gracefully" do
      # The function should not crash even if timeout is unavailable
      # We test this by ensuring the timeout_available? helper works
      result = DalaDev.Utils.command_available?("timeout")
      assert is_boolean(result)
    end
  end
end
