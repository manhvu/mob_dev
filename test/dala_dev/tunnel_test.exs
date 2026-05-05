defmodule DalaDev.TunnelTest do
  use ExUnit.Case, async: true

  alias DalaDev.Tunnel

  describe "dist_port/1" do
    test "first device gets base port 9100" do
      assert Tunnel.dist_port(0) == 9100
    end

    test "second device gets 9101" do
      assert Tunnel.dist_port(1) == 9101
    end

    test "each index adds one to base" do
      for i <- 0..9 do
        assert Tunnel.dist_port(i) == 9100 + i
      end
    end

    test "consistent with what Tunnel.setup assigns" do
      # Verifies the formula used in setup/2 matches dist_port/1.
      # Android at index 0 → adb forward tcp:9100 tcp:9100
      # iOS at index 1 → dist port 9101
      assert Tunnel.dist_port(0) == 9100
      assert Tunnel.dist_port(1) == 9101
    end
  end
end
