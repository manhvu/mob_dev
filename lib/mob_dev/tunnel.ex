defmodule MobDev.Tunnel do
  @moduledoc """
  Manages adb port tunnels for Android devices.

  For each device:
    adb reverse tcp:4369 tcp:4369   — Android BEAM registers in Mac's EPMD
    adb forward tcp:<dist> tcp:9100 — Mac reaches device's dist port
  """

  alias MobDev.Device

  # EPMD port — shared across all devices (same Mac EPMD).
  @epmd_port 4369

  # Base dist port — each device gets an offset so they don't collide.
  @base_dist_port 9100

  @doc """
  Assigns a dist port and sets up adb tunnels for a device.
  Returns {:ok, %Device{}} with dist_port filled in, or {:error, reason}.
  """
  def setup(device, index \\ 0)

  def setup(%Device{platform: :android, serial: serial} = device, index) do
    dist_port = @base_dist_port + index

    with :ok <- reverse(serial, @epmd_port, @epmd_port),
         :ok <- forward(serial, dist_port, @base_dist_port) do
      {:ok, %{device | dist_port: dist_port, status: :tunneled}}
    end
  end

  def setup(%Device{platform: :ios} = device, index) do
    # iOS simulator shares Mac network stack — no adb tunnels needed.
    # Port is offset by index so iOS and Android don't share the same dist port.
    # (Android's adb forward also binds that port on Mac's loopback, causing conflict.)
    # Physical iOS via iproxy is a future addition.
    dist_port = @base_dist_port + index
    {:ok, %{device | dist_port: dist_port, status: :tunneled}}
  end

  @doc "Returns the dist port for a given device index (same formula used in setup/2)."
  def dist_port(index), do: @base_dist_port + index

  @doc "Tears down adb tunnels for a device."
  def teardown(%Device{platform: :android, serial: serial, dist_port: dist_port}) do
    run_adb(["-s", serial, "reverse", "--remove", "tcp:#{@epmd_port}"])
    run_adb(["-s", serial, "forward", "--remove", "tcp:#{dist_port}"])
    :ok
  end

  def teardown(%Device{platform: :ios}), do: :ok

  # adb reverse tcp:remote tcp:local  (device→Mac)
  defp reverse(serial, device_port, local_port) do
    case run_adb(["-s", serial, "reverse",
                  "tcp:#{device_port}", "tcp:#{local_port}"]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "reverse #{device_port}: #{reason}"}
    end
  end

  # adb forward tcp:local tcp:remote  (Mac→device)
  defp forward(serial, local_port, device_port) do
    case run_adb(["-s", serial, "forward",
                  "tcp:#{local_port}", "tcp:#{device_port}"]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "forward #{local_port}→#{device_port}: #{reason}"}
    end
  end

  defp run_adb(args) do
    case System.cmd("adb", args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end
end
