defmodule MobDev.NativeBuild do
  @moduledoc """
  Builds native binaries (APK for Android, .app bundle for iOS simulator)
  for the current Mob project.

  Reads paths from `mob.exs` in the project root. If `mob.exs` is missing
  or paths haven't been configured, prints instructions and exits.

  ## mob.exs keys

    * `:otp_src`           — OTP source tree (headers + boot scripts)
    * `:mob_dir`           — mob library repo (native C/ObjC/Swift source)
    * `:elixir_lib`        — Elixir stdlib lib dir
    * `:ios_otp_root`      — iOS OTP runtime root (default `/tmp/otp-ios-sim`)
    * `:android_otp_release` — Android OTP release dir (default `/tmp/otp-android`)
  """

  @doc """
  Builds native binaries for all platforms present in the project.
  Runs Android Gradle build if `android/` dir exists.
  Runs iOS build script if `ios/build.sh` exists.
  """
  def build_all do
    cfg = load_config()

    results = []
    results = if File.dir?("android"),    do: [build_android(cfg) | results], else: results
    results = if File.exists?("ios/build.sh"), do: [build_ios(cfg) | results], else: results

    if results == [] do
      IO.puts("  #{IO.ANSI.yellow()}No native build targets found (missing android/ or ios/build.sh)#{IO.ANSI.reset()}")
    end

    Enum.each(results, fn
      {:ok, platform} ->
        IO.puts("  #{IO.ANSI.green()}✓ #{platform} native build complete#{IO.ANSI.reset()}")
      {:error, platform, reason} ->
        IO.puts("  #{IO.ANSI.red()}✗ #{platform} native build failed: #{reason}#{IO.ANSI.reset()}")
    end)

    ok_count = Enum.count(results, &match?({:ok, _}, &1))
    ok_count == length(results)
  end

  # ── Android ──────────────────────────────────────────────────────────────────

  defp build_android(cfg) do
    IO.puts("  Building Android APK...")
    bundle_id = "com.mob.#{app_name()}"
    apk = "android/app/build/outputs/apk/debug/app-debug.apk"

    with :ok <- ensure_otp_release(cfg),
         :ok <- gradle_assemble(),
         :ok <- adb_install_all(apk, bundle_id) do
      {:ok, "Android"}
    else
      {:error, reason} -> {:error, "Android", reason}
    end
  end

  defp ensure_otp_release(cfg) do
    otp_src     = cfg[:otp_src]
    otp_release = cfg[:android_otp_release]
    elixir_lib  = cfg[:elixir_lib]

    with :ok <- check_path(otp_src, "otp_src"),
         :ok <- check_path(elixir_lib, "elixir_lib") do
      File.mkdir_p!("#{otp_release}/releases/29")

      cp("#{otp_src}/erts/start_scripts/start_clean.boot", "#{otp_release}/releases/29/")
      cp("#{otp_src}/erts/start_scripts/start_sasl.boot",  "#{otp_release}/releases/29/")

      # erts BEAMs
      for dest <- Path.wildcard("#{otp_release}/lib/erts-*/ebin") do
        System.cmd("cp", ["-r", "#{otp_src}/erts/ebin/.", dest], stderr_to_stdout: true)
      end

      # ERTS binaries
      for dest <- Path.wildcard("#{otp_release}/erts-*/bin") do
        android_bins = Path.join(otp_src, "bin/aarch64-unknown-linux-android")
        if File.dir?(android_bins) do
          System.cmd("cp", ["-r", "#{android_bins}/.", dest], stderr_to_stdout: true)
        end
      end

      :ok
    end
  end

  defp gradle_assemble do
    IO.puts("  Running Gradle assembleDebug...")
    case System.cmd("./gradlew", ["assembleDebug", "-q"],
                    cd: "android", stderr_to_stdout: true) do
      {_, 0}   -> :ok
      {out, _} -> {:error, "Gradle failed:\n#{String.slice(out, -500, 500)}"}
    end
  end

  defp adb_install_all(apk, bundle_id) do
    case System.cmd("adb", ["devices"], stderr_to_stdout: true) do
      {output, 0} ->
        serials =
          output
          |> String.split("\n")
          |> Enum.drop(1)
          |> Enum.filter(&String.contains?(&1, "\tdevice"))
          |> Enum.map(&hd(String.split(&1, "\t")))

        Enum.each(serials, fn serial ->
          IO.puts("  Installing APK on #{serial}...")
          System.cmd("adb", ["-s", serial, "shell", "am", "force-stop", bundle_id],
                     stderr_to_stdout: true)
          System.cmd("adb", ["-s", serial, "uninstall", bundle_id], stderr_to_stdout: true)
          System.cmd("adb", ["-s", serial, "install", apk], stderr_to_stdout: true)
        end)

        :ok

      {out, _} ->
        {:error, "adb devices failed: #{out}"}
    end
  end

  # ── iOS ──────────────────────────────────────────────────────────────────────

  defp build_ios(_cfg) do
    IO.puts("  Building iOS simulator app...")
    case System.cmd("bash", ["ios/build.sh"], stderr_to_stdout: true, into: IO.stream()) do
      {_, 0}   -> {:ok, "iOS"}
      {_, _}   -> {:error, "iOS", "build.sh failed — check output above"}
    end
  end

  # ── Config ───────────────────────────────────────────────────────────────────

  defp load_config do
    config_file = Path.join(File.cwd!(), "mob.exs")

    unless File.exists?(config_file) do
      Mix.raise("""
      mob.exs not found in #{File.cwd!()}.

      Create mob.exs with your local paths:

          import Config

          config :mob_dev,
            otp_src:    "/path/to/otp",
            mob_dir:    "/path/to/mob",
            elixir_lib: "/path/to/elixir/lib"

      mob.exs is gitignored — each developer sets their own paths.
      """)
    end

    Config.Reader.read!(config_file)
    |> Keyword.get(:mob_dev, [])
    |> Keyword.merge(
      ios_otp_root:        "/tmp/otp-ios-sim",
      android_otp_release: "/tmp/otp-android"
    )
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp app_name, do: Mix.Project.config()[:app] |> to_string()

  defp check_path(path, key) do
    cond do
      is_nil(path) or path =~ "/path/to/" ->
        {:error, "#{key} not configured in mob.exs"}
      not File.exists?(path) ->
        {:error, "#{key} path not found: #{path}"}
      true ->
        :ok
    end
  end

  defp cp(src, dest) do
    System.cmd("cp", [src, dest], stderr_to_stdout: true)
  end
end
