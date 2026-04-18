defmodule MobDev.Device do
  @moduledoc """
  Represents a connected or available device (physical or emulator/simulator).
  """

  @type t :: %__MODULE__{}

  @enforce_keys [:platform, :serial]
  defstruct [
    :platform,    # :android | :ios
    :serial,      # "emulator-5554" | "R5CW3089HVB" | "78354490-EF38-..."
    :name,        # "Pixel 8" | "iPhone 17"
    :version,     # "Android 15" | "iOS 18"
    :type,        # :emulator | :simulator | :physical
    :node,        # :"mob_demo_android@127.0.0.1"
    :dist_port,   # 9100
    :status,      # :discovered | :unauthorized | :tunneled | :connected | :error
    :error        # error message string if status == :error
  ]

  @doc """
  Derives a short identifier from a serial for use in node names.

    iex> MobDev.Device.short_id("emulator-5554")
    "5554"

    iex> MobDev.Device.short_id("R5CW3089HVB")
    "HVBA"  # last 4 chars, uppercased

    iex> MobDev.Device.short_id("78354490-EF38-44D7-A437-DD941C20524D")
    "524D"
  """
  @spec short_id(String.t()) :: String.t()
  def short_id(serial) do
    serial
    |> String.replace("-", "")
    |> String.slice(-4..-1)
    |> String.upcase()
  end

  @doc """
  Returns the Erlang node name atom for a device.
  Uses 127.0.0.1 for USB-connected devices (tunneled).

  Node names are `<app>_<platform>@127.0.0.1` where `<app>` is the OTP
  application name from the current Mix project (e.g. `my_app_android@127.0.0.1`).

  Multi-device support (where unique per-device names are needed) is future work
  and will require the app to receive its node name dynamically via intent extras.
  """
  @spec node_name(t()) :: atom()
  def node_name(%__MODULE__{platform: :android}) do
    :"#{app_name()}_android@127.0.0.1"
  end

  def node_name(%__MODULE__{platform: :ios}) do
    :"#{app_name()}_ios@127.0.0.1"
  end

  defp app_name, do: Mix.Project.config()[:app]

  @doc "Human-readable one-line summary."
  @spec summary(t()) :: String.t()
  def summary(%__MODULE__{} = d) do
    type_label = case d.type do
      :emulator  -> "emulator"
      :simulator -> "simulator"
      :physical  -> "physical"
      nil        -> "device"
    end
    status_icon = case d.status do
      :connected   -> "✓"
      :tunneled    -> "⟳"
      :discovered  -> "·"
      :unauthorized -> "✗"
      :error       -> "!"
      _            -> "?"
    end
    name = d.name || d.serial
    version = if d.version, do: " (#{d.version})", else: ""
    "#{status_icon} #{name}#{version}  [#{type_label}]  #{d.serial}"
  end
end
