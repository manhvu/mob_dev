defmodule Mix.Tasks.Dala.Screen do
  use Mix.Task

  @shortdoc "Capture screenshots, record video, or preview screen from mobile devices"

  @moduledoc """
  Capture screenshots, record screen video, or start live screen preview
  from connected mobile devices.

  ## Examples

      # Take a screenshot (auto-detects device)
      mix dala.screen --capture

      # Save screenshot to file
      mix dala.screen --capture screenshot.png

      # Record 30 seconds of video
      mix dala.screen --record --duration 30

      # Start live preview in browser
      mix dala.screen --preview

      # Specify device by node
      mix dala.screen --node dala_qa@192.168.1.5 --capture

      # List available devices
      mix dala.screen --list

  ## Options

    * `--capture` - Take a screenshot
    * `--record` - Record screen video
    * `--preview` - Start live screen preview
    * `--node` - Target device node or serial
    * `--duration` - Recording duration in seconds (default: 30)
    * `--save-as` - Output file path
    * `--list` - List available devices
    * `--port` - Preview server port (default: 5050)
  """

  alias DalaDev.{ScreenCapture, Discovery}

  @impl Mix.Task
  def run(args) do
    {opts, _} =
      OptionParser.parse!(args,
        strict: [
          capture: :boolean,
          record: :boolean,
          preview: :boolean,
          node: :string,
          duration: :integer,
          save_as: :string,
          list: :boolean,
          port: :integer
        ],
        aliases: [
          c: :capture,
          r: :record,
          p: :preview,
          n: :node,
          d: :duration,
          s: :save_as
        ]
      )

    cond do
      Keyword.get(opts, :list, false) ->
        list_devices()

      Keyword.get(opts, :preview, false) ->
        start_preview(opts)

      Keyword.get(opts, :record, false) ->
        record_screen(opts)

      Keyword.get(opts, :capture, false) or Keyword.has_key?(opts, :save_as) ->
        capture_screen(opts)

      true ->
        show_usage()
    end
  end

  defp list_devices do
    android = Discovery.Android.list_devices()
    ios = Discovery.IOS.list_devices()

    if android == [] and ios == [] do
      Mix.shell().info("No devices found.")
      Mix.shell().info("Connect an Android device or start an iOS simulator.")
    else
      Mix.shell().info("Available devices:\n")

      Enum.each(android, fn device ->
        Mix.shell().info("  Android: #{device.name || device.serial} (#{device.serial})")
      end)

      Enum.each(ios, fn device ->
        Mix.shell().info("  iOS: #{device.name || device.serial} (#{device.serial})")
      end)
    end
  end

  defp start_preview(opts) do
    device_ref = get_device_ref(opts)

    case ScreenCapture.live_preview(device_ref, port: Keyword.get(opts, :port, 5050)) do
      {:ok, _pid} ->
        Mix.shell().info("\nPress Ctrl+C to stop the preview server.")

        # Keep running until user interrupts
        Process.sleep(:infinity)

      {:error, reason} ->
        Mix.shell().error("Failed to start preview: #{inspect(reason)}")
    end
  rescue
    e ->
      Mix.shell().error("Error: #{Exception.message(e)}")
  end

  defp capture_screen(opts) do
    device_ref = get_device_ref(opts)
    save_as = Keyword.get(opts, :save_as)

    capture_opts =
      if save_as do
        [save_as: save_as]
      else
        []
      end

    Mix.shell().info("Capturing screenshot...")

    case ScreenCapture.capture(device_ref, capture_opts) do
      {:ok, path} when is_binary(path) ->
        Mix.shell().info("Screenshot saved to: #{path}")

      {:ok, png_data} when is_binary(png_data) ->
        if save_as do
          File.write!(save_as, png_data)
          Mix.shell().info("Screenshot saved to: #{save_as}")
        else
          Mix.shell().info("Screenshot captured (#{byte_size(png_data)} bytes)")
          Mix.shell().info("Use --save-as to save to file")
        end

      {:error, reason} ->
        Mix.shell().error("Failed to capture screenshot: #{inspect(reason)}")
    end
  end

  defp record_screen(opts) do
    device_ref = get_device_ref(opts)
    duration = Keyword.get(opts, :duration, 30)
    save_as = Keyword.get(opts, :save_as, "screen_record_#{timestamp()}.mp4")

    Mix.shell().info("Recording for #{duration} seconds...")

    record_opts = [duration: duration, save_as: save_as]

    case ScreenCapture.record(device_ref, record_opts) do
      {:ok, path} ->
        Mix.shell().info("\nRecording saved to: #{path}")

      {:error, reason} ->
        Mix.shell().error("Failed to record: #{inspect(reason)}")
    end
  end

  defp get_device_ref(opts) do
    case Keyword.get(opts, :node) do
      nil ->
        # Auto-detect first available device
        devices = DalaDev.Discovery.Android.list_devices() ++ DalaDev.Discovery.IOS.list_devices()

        case devices do
          [] ->
            Mix.raise("No devices found. Connect a device or use --node to specify one.")

          [device | _] ->
            Mix.shell().info("Using device: #{device.name || device.serial}")
            device
        end

      node_str ->
        # Try to parse as node atom, or use as serial
        case node_str do
          "dala_qa@" <> _ = node_str -> String.to_atom(node_str)
          _ -> node_str
        end
    end
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.to_unix()
  end

  defp show_usage do
    Mix.shell().info("""
    Usage: mix Dala.Screen [OPTIONS]

    Options:
      --capture, -c           Take a screenshot
      --record, -r            Record screen video
      --preview, -p           Start live screen preview
      --node, -n <node>       Target device node or serial
      --duration, -d <secs>   Recording duration (default: 30)
      --save-as, -s <path>    Output file path
      --port <port>           Preview server port (default: 5050)
      --list                  List available devices

    Examples:
      mix Dala.Screen --capture
      mix Dala.Screen --record --duration 60
      mix Dala.Screen --preview --port 8080
    """)
  end
end
