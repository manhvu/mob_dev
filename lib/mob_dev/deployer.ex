defmodule MobDev.Deployer do
  @moduledoc """
  Pushes compiled BEAM files from `_build/dev/lib/*/ebin/` to connected devices.

  Does NOT rebuild APKs or recompile native code — that's `deploy.sh` (first-time setup).
  Use this for day-to-day code iteration: edit Elixir → `mix mob.deploy` → code running.

  ## Platform behaviour

  **Android**: pushes via `adb push` (requires `adb root`, i.e. emulator or debug build),
  or falls back to `adb push` → `/data/local/tmp/` → `run-as tar xf` for real devices.

  **iOS simulator**: copies files locally into `/tmp/otp-ios-sim/beamhello/` (no network
  hop — the simulator shares the Mac filesystem).
  """

  alias MobDev.Discovery.{Android, IOS}
  alias MobDev.Device

  @android_activity ".MainActivity"
  @ios_beamhello    "/tmp/otp-ios-sim/beamhello"

  defp app_name,         do: Mix.Project.config()[:app] |> to_string()
  defp bundle_id,        do: "com.mob.#{app_name()}"
  defp android_package,  do: bundle_id()
  defp android_app_data, do: "/data/data/#{android_package()}/files"
  defp ios_bundle_id,    do: bundle_id()

  @doc """
  Discovers devices, pushes BEAMs, and optionally restarts apps.
  Returns `{deployed, failed}` lists of `%Device{}`.
  """
  def deploy_all(opts \\ []) do
    restart = Keyword.get(opts, :restart, true)
    beam_dirs = collect_beam_dirs()

    android = Android.list_devices() |> Enum.reject(&(&1.status == :unauthorized))
    ios     = IOS.list_simulators()
    all     = android ++ ios

    if all == [] do
      IO.puts("  #{color(:yellow)}No devices found.#{color(:reset)}")
      {[], []}
    else
      IO.puts("  Pushing #{count_beams(beam_dirs)} BEAM file(s) to #{length(all)} device(s)...")

      results = all |> Enum.with_index() |> Enum.map(fn {device, idx} ->
        IO.write("  #{device.name || device.serial}  →  pushing...")
        dist_port = MobDev.Tunnel.dist_port(idx)
        result = case device.platform do
          :android -> deploy_android(device, beam_dirs, restart: restart, dist_port: dist_port)
          :ios     -> deploy_ios(device, beam_dirs, restart: restart, dist_port: dist_port)
        end
        case result do
          {:ok, d}         -> IO.puts("  #{color(:green)}✓#{color(:reset)}"); {:ok, d}
          {:error, reason} ->
            IO.puts("  #{color(:red)}✗#{color(:reset)}")
            IO.puts("    #{color(:red)}#{reason}#{color(:reset)}")
            {:error, %{device | status: :error, error: reason}}
        end
      end)

      deployed = for {:ok, d} <- results, do: d
      failed   = for {:error, d} <- results, do: d
      {deployed, failed}
    end
  end

  # ── Android ─────────────────────────────────────────────────────────────────

  defp deploy_android(%Device{serial: serial} = device, beam_dirs, opts) do
    restart   = Keyword.get(opts, :restart, true)
    dist_port = Keyword.get(opts, :dist_port, 9100)

    case push_beams_android(serial, beam_dirs) do
      :ok ->
        if restart, do: restart_android(serial, dist_port: dist_port)
        {:ok, device}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp push_beams_android(serial, beam_dirs) do
    # Try adb root first (works on emulators and eng builds).
    case run_adb(["-s", serial, "root"]) do
      {:ok, _} ->
        :timer.sleep(600)
        Enum.reduce_while(beam_dirs, :ok, fn dir, _ ->
          case run_adb(["-s", serial, "push", "#{dir}/.",
                        "#{android_app_data()}/otp/beamhello/"]) do
            {:ok, _}        -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, "push failed: #{reason}"}}
          end
        end)

      {:error, _} ->
        # Fall back to run-as tar (non-rooted physical devices).
        push_beams_android_runas(serial, beam_dirs)
    end
  end

  defp push_beams_android_runas(serial, beam_dirs) do
    stage_local = System.tmp_dir!() |> Path.join("mob_beams_#{serial}.tar")
    stage_device = "/data/local/tmp/mob_beams.tar"

    try do
      tmp = Path.join(System.tmp_dir!(), "mob_beam_stage_#{serial}")
      File.rm_rf!(tmp)
      File.mkdir_p!(tmp)

      Enum.each(beam_dirs, fn dir ->
        System.cmd("cp", ["-r", "#{dir}/.", tmp], stderr_to_stdout: true)
      end)

      case System.cmd("tar", ["cf", stage_local, "-C", Path.dirname(tmp),
                               Path.basename(tmp)], stderr_to_stdout: true) do
        {_, 0} -> :ok
        {out, _} -> throw({:error, "tar create failed: #{out}"})
      end

      case run_adb(["-s", serial, "push", stage_local, stage_device]) do
        {:ok, _} -> :ok
        {:error, r} -> throw({:error, "adb push failed: #{r}"})
      end

      cmd = "run-as #{android_package()} tar xf #{stage_device} " <>
            "-C #{android_app_data()}/otp/beamhello/ --strip-components=1"
      case run_adb(["-s", serial, "shell", cmd]) do
        {:ok, _} -> :ok
        {:error, r} -> throw({:error, "run-as tar failed: #{r}"})
      end

      run_adb(["-s", serial, "shell", "rm -f #{stage_device}"])
      :ok
    catch
      {:error, reason} -> {:error, reason}
    after
      File.rm(stage_local)
    end
  end

  defp restart_android(serial, opts) do
    dist_port = Keyword.get(opts, :dist_port, 9100)
    run_adb(["-s", serial, "shell", "am", "force-stop", android_package()])
    :timer.sleep(300)
    run_adb(["-s", serial, "shell", "am", "start",
             "-n", "#{android_package()}/#{@android_activity}",
             "--ei", "mob_dist_port", to_string(dist_port)])
    :ok
  end

  # ── iOS ─────────────────────────────────────────────────────────────────────

  defp deploy_ios(%Device{serial: udid} = device, beam_dirs, opts) do
    restart   = Keyword.get(opts, :restart, true)
    dist_port = Keyword.get(opts, :dist_port, 9100)

    try do
      File.mkdir_p!(@ios_beamhello)
      Enum.each(beam_dirs, fn dir ->
        case System.cmd("cp", ["-r", "#{dir}/.", @ios_beamhello], stderr_to_stdout: true) do
          {_, 0} -> :ok
          {out, _} -> throw({:error, "cp failed: #{out}"})
        end
      end)

      if restart do
        IOS.terminate_app(udid, ios_bundle_id())
        :timer.sleep(300)
        IOS.launch_app(udid, ios_bundle_id(), dist_port: dist_port)
      end

      {:ok, device}
    catch
      {:error, reason} -> {:error, reason}
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp collect_beam_dirs do
    case File.ls("_build/dev/lib") do
      {:ok, libs} ->
        libs
        |> Enum.map(&"_build/dev/lib/#{&1}/ebin")
        |> Enum.filter(&File.dir?/1)
      {:error, _} -> []
    end
  end

  defp count_beams(beam_dirs) do
    Enum.reduce(beam_dirs, 0, fn dir, acc ->
      case File.ls(dir) do
        {:ok, files} -> acc + Enum.count(files, &String.ends_with?(&1, ".beam"))
        _ -> acc
      end
    end)
  end

  defp run_adb(args) do
    case System.cmd("adb", args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  defp color(:green),  do: IO.ANSI.green()
  defp color(:yellow), do: IO.ANSI.yellow()
  defp color(:red),    do: IO.ANSI.red()
  defp color(:reset),  do: IO.ANSI.reset()
end
