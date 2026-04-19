defmodule MobDev.DeviceTest do
  use ExUnit.Case, async: true

  alias MobDev.Device

  # ── short_id/1 ──────────────────────────────────────────────────────────────

  describe "short_id/1" do
    test "extracts last 4 chars from emulator serial" do
      assert Device.short_id("emulator-5554") == "5554"
    end

    test "extracts last 4 chars from physical device serial" do
      assert Device.short_id("R5CW3089HVB") == "9HVB"
    end

    test "extracts last 4 chars from iOS simulator UUID" do
      assert Device.short_id("78354490-EF38-44D7-A437-DD941C20524D") == "524D"
    end

    test "strips dashes before slicing" do
      # "R5CW3089HVB" → no dashes → last 4 = "HVBA"
      # Make sure dashes from UUID don't end up in the id
      id = Device.short_id("AABB-CCDD")
      refute String.contains?(id, "-")
    end

    test "uppercases the result" do
      assert Device.short_id("abcdef") == "CDEF"
    end
  end

  # ── node_name/1 ─────────────────────────────────────────────────────────────

  describe "node_name/1" do
    test "returns android node name for android device" do
      app = Mix.Project.config()[:app]
      device = %Device{platform: :android, serial: "emulator-5554"}
      assert Device.node_name(device) == :"#{app}_android@127.0.0.1"
    end

    test "returns ios node name for ios device" do
      app = Mix.Project.config()[:app]
      device = %Device{platform: :ios, serial: "78354490-EF38-44D7-A437-DD941C20524D"}
      assert Device.node_name(device) == :"#{app}_ios@127.0.0.1"
    end

    test "android node name uses 127.0.0.1" do
      device = %Device{platform: :android, serial: "any"}
      assert device |> Device.node_name() |> to_string() |> String.ends_with?("@127.0.0.1")
    end

    test "ios node name uses 127.0.0.1" do
      device = %Device{platform: :ios, serial: "any"}
      assert device |> Device.node_name() |> to_string() |> String.ends_with?("@127.0.0.1")
    end
  end

  # ── summary/1 ───────────────────────────────────────────────────────────────

  describe "summary/1" do
    test "includes device name when set" do
      device = %Device{platform: :android, serial: "emulator-5554",
                       name: "Pixel 8", type: :emulator, status: :discovered}
      assert Device.summary(device) =~ "Pixel 8"
    end

    test "falls back to serial when name is nil" do
      device = %Device{platform: :android, serial: "emulator-5554",
                       type: :emulator, status: :discovered}
      assert Device.summary(device) =~ "emulator-5554"
    end

    test "includes version when set" do
      device = %Device{platform: :android, serial: "s", name: "Pixel",
                       version: "Android 15", type: :emulator, status: :discovered}
      assert Device.summary(device) =~ "Android 15"
    end

    test "shows ✓ for connected status" do
      device = %Device{platform: :android, serial: "s", type: :emulator, status: :connected}
      assert Device.summary(device) =~ "✓"
    end

    test "shows ✗ for unauthorized status" do
      device = %Device{platform: :android, serial: "s", type: :physical, status: :unauthorized}
      assert Device.summary(device) =~ "✗"
    end

    test "shows ! for error status" do
      device = %Device{platform: :android, serial: "s", type: :emulator, status: :error}
      assert Device.summary(device) =~ "!"
    end

    test "includes type label" do
      emulator = %Device{platform: :android, serial: "s", type: :emulator, status: :discovered}
      simulator = %Device{platform: :ios, serial: "s", type: :simulator, status: :discovered}
      physical = %Device{platform: :android, serial: "s", type: :physical, status: :discovered}

      assert Device.summary(emulator) =~ "emulator"
      assert Device.summary(simulator) =~ "simulator"
      assert Device.summary(physical) =~ "physical"
    end
  end
end
