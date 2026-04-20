defmodule MobDev.Deployer do
  @moduledoc """
  Pushes compiled BEAM files from `_build/dev/lib/*/ebin/` to connected devices.

  Does NOT rebuild APKs or recompile native code — that's `deploy.sh` (first-time setup).
  Use this for day-to-day code iteration: edit Elixir → `mix mob.deploy` → code running.

  ## Transport selection

  **Erlang dist (preferred)**: when a device node is already reachable via Erlang
  distribution, BEAMs are hot-loaded via RPC. No restart needed — modules are
  loaded in place exactly like `nl/1` in IEx.

  **adb push / cp (fallback)**: when no dist connection exists (first deploy, app not
  running), falls back to the traditional push-then-restart path.

  ## Platform behaviour

  **Android**: pushes via `adb push` (requires `adb root`, i.e. emulator or debug build),
  or falls back to `adb push` → `/data/local/tmp/` → `run-as tar xf` for real devices.

  **iOS simulator**: copies files locally into `/tmp/otp-ios-sim/beamhello/` (no network
  hop — the simulator shares the Mac filesystem).
  """

  alias MobDev.Discovery.{Android, IOS}
  alias MobDev.{Device, HotPush, Tunnel}

  @cookie :mob_secret

  @android_activity ".MainActivity"

  defp app_name,          do: Mix.Project.config()[:app] |> to_string()
  defp bundle_id,         do: MobDev.Config.bundle_id()
  defp android_package,   do: bundle_id()
  defp android_app_data,  do: "/data/data/#{android_package()}/files"
  defp android_beams_dir, do: "#{android_app_data()}/otp/#{app_name()}"
  defp ios_bundle_id,     do: bundle_id()
  defp ios_beams_dir do
    # mob_beam.m hardcodes /tmp/otp-ios-sim as OTP_ROOT.
    # If that directory exists (manually set up or from a prior native deploy),
    # deploy beams there so the running BEAM picks them up immediately.
    # Fall back to the cache dir otherwise (e.g. fresh machine before first --native).
    tmp_path   = Path.join("/tmp/otp-ios-sim", app_name())
    cache_path = Path.join(MobDev.OtpDownloader.ios_sim_otp_dir(), app_name())
    if File.dir?("/tmp/otp-ios-sim"), do: tmp_path, else: cache_path
  end

  @doc """
  Discovers devices, pushes BEAMs, and optionally restarts apps.
  Returns `{deployed, failed}` lists of `%Device{}`.
  """
  @spec deploy_all(keyword()) :: {[Device.t()], [Device.t()]}
  def deploy_all(opts \\ []) do
    restart   = Keyword.get(opts, :restart, true)
    platforms = Keyword.get(opts, :platforms, [:android, :ios])
    force_fs  = Keyword.get(opts, :force_fs, false)
    beam_dirs = collect_beam_dirs()

    android = if :android in platforms,
                do: Android.list_devices() |> Enum.reject(&(&1.status == :unauthorized)),
                else: []
    ios     = if :ios in platforms, do: IOS.list_simulators(), else: []
    all     = android ++ ios

    if all == [] do
      IO.puts("  #{color(:yellow)}No devices found.#{color(:reset)}")
      {[], []}
    else
      IO.puts("  Pushing #{count_beams(beam_dirs)} BEAM file(s) to #{length(all)} device(s)...")

      # Try Erlang dist first — hot-loads modules with no restart. We set up
      # tunnels and attempt Node.connect for each device; those that respond
      # get BEAMs via RPC, the rest fall back to adb/cp + restart.
      # force_fs: true skips dist and always writes to the filesystem — required
      # after a native build/install where the old BEAM process is dead.
      dist_nodes = if force_fs, do: [], else: connect_dist(all)

      results = all |> Enum.with_index() |> Enum.map(fn {device, idx} ->
        IO.write("  #{device.name || device.serial}  →  pushing...")
        dist_port = Tunnel.dist_port(idx)
        node      = Device.node_name(device)

        {method, result} =
          if node in dist_nodes do
            {:dist, push_via_dist(node, device)}
          else
            fallback = case device.platform do
              :android -> deploy_android(device, beam_dirs, restart: restart, dist_port: dist_port)
              :ios     -> deploy_ios(device, beam_dirs, restart: restart, dist_port: dist_port)
            end
            {:adb, fallback}
          end

        case result do
          {:ok, d} ->
            suffix = if method == :dist, do: " (dist, no restart)", else: ""
            IO.puts(" #{color(:green)}✓#{suffix}#{color(:reset)}")
            {:ok, d}
          {:error, reason} ->
            IO.puts(" #{color(:red)}✗#{color(:reset)}")
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
    # Check the output text — non-rooted devices return exit 0 with
    # "cannot run as root in production builds".
    rooted? = case run_adb(["-s", serial, "root"]) do
      {:ok, out} -> out =~ "restarting" or out =~ "already running as root"
      _          -> false
    end

    if rooted? do
      :timer.sleep(600)
      run_adb(["-s", serial, "shell", "mkdir -p #{android_beams_dir()}"])
      result = Enum.reduce_while(beam_dirs, :ok, fn dir, _ ->
        case run_adb(["-s", serial, "push", "#{Path.expand(dir)}/.",
                      "#{android_beams_dir()}/"]) do
          {:ok, _}        -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, "push failed: #{reason}"}}
        end
      end)
      # Fix SELinux MCS categories on pushed files. adb push (as root) labels
      # files with the root process's categories, not the app's. restorecon
      # only restores the type label — it cannot fix MCS categories. We use
      # chcon with the context from the app's own files/ directory instead.
      run_adb(["-s", serial, "shell",
        "chcon -hR $(stat -c %C #{android_app_data()}) #{android_app_data()}/otp"])
      result
    else
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

      run_adb(["-s", serial, "shell",
               "run-as #{android_package()} mkdir -p #{android_beams_dir()}"])

      cmd = "run-as #{android_package()} tar xf #{stage_device} " <>
            "-C #{android_beams_dir()}/ --strip-components=1"
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
    # Heal SELinux MCS category mismatch before start — APK reinstall changes
    # the app's category but leaves OTP files with stale labels. chcon copies
    # the correct context from the app's own files/ directory.
    run_adb(["-s", serial, "shell",
      "chcon -hR $(stat -c %C #{android_app_data()}) #{android_app_data()}/otp"])
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
      File.mkdir_p!(ios_beams_dir())
      Enum.each(beam_dirs, fn dir ->
        abs_dir = Path.expand(dir)
        case System.cmd("cp", ["-r", "#{abs_dir}/.", ios_beams_dir()], stderr_to_stdout: true) do
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

  # ── Dist push ────────────────────────────────────────────────────────────────

  # Try to connect via Erlang dist to each discovered device. Returns a list of
  # connected node atoms. Devices that don't respond are left for the adb fallback.
  defp connect_dist(devices) do
    ensure_local_dist()
    Enum.flat_map(devices, fn device ->
      node = Device.node_name(device)
      Node.set_cookie(node, @cookie)
      if Node.connect(node), do: [node], else: []
    end)
  rescue
    _ -> []
  end

  defp ensure_local_dist do
    unless Node.alive?() do
      Node.start(:"mob_dev@127.0.0.1", :longnames)
      Node.set_cookie(@cookie)
    end
  end

  # Push all compiled BEAMs to a single dist-connected node.
  defp push_via_dist(node, device) do
    {_pushed, failed} = HotPush.push_all([node])
    if failed == [] do
      {:ok, device}
    else
      mods = Enum.map_join(failed, ", ", fn {mod, _} -> inspect(mod) end)
      {:error, "dist push failed for: #{mods}"}
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
