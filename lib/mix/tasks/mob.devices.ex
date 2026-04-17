defmodule Mix.Tasks.Mob.Devices do
  use Mix.Task

  @shortdoc "List all connected Android and iOS devices"

  @moduledoc """
  Scans for connected Android devices (via adb) and iOS simulators
  (via xcrun simctl) and prints their status.

      mix mob.devices

  Useful for diagnosing connection issues before running mix mob.connect.

  ## Under the hood

      # Android
      adb devices -l
      # → parses serial numbers, device/emulator state, and manufacturer/model

      # iOS (macOS only)
      xcrun simctl list devices --json
      # → filters for Booted simulators with device name and UDID

  You can run either command directly to get the raw output. `mix mob.devices`
  adds status hints (e.g. "enable Developer Mode", "check USB debugging prompt").
  """

  alias MobDev.Discovery.{Android, IOS}
  alias MobDev.Device

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")

    android = Android.list_devices()
    ios     = IOS.list_devices()

    IO.puts("\n#{IO.ANSI.cyan()}Android#{IO.ANSI.reset()}")

    if android == [] do
      IO.puts("  (none — is adb installed? Any devices connected?)")
    else
      Enum.each(android, fn d ->
        IO.puts("  " <> Device.summary(d))
        print_android_hints(d)
      end)
    end

    IO.puts("\n#{IO.ANSI.cyan()}iOS#{IO.ANSI.reset()}")

    if ios == [] do
      IO.puts("  (none — is a simulator running?)")
    else
      Enum.each(ios, fn d ->
        IO.puts("  " <> Device.summary(d))
      end)
    end

    IO.puts("")
  end

  defp print_android_hints(%{status: :unauthorized}) do
    IO.puts("    #{IO.ANSI.yellow()}→ Check device for 'Allow USB debugging?' prompt#{IO.ANSI.reset()}")
  end

  defp print_android_hints(%{platform: :android, serial: serial}) do
    case Android.developer_mode(serial) do
      :disabled ->
        IO.puts("    #{IO.ANSI.yellow()}→ Enable Developer Mode: Settings → About → tap Build Number 7×#{IO.ANSI.reset()}")
      _ -> :ok
    end
  end

  defp print_android_hints(_), do: :ok
end
