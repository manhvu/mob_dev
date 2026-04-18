defmodule MobDev.OtpDownloader do
  @moduledoc """
  Downloads and caches pre-built OTP releases from GitHub for Android and iOS simulator.

  Artifacts are cached at `~/.mob/cache/` and reused across projects.
  """

  @otp_hash    "73ba6e0f"
  @release_tag "otp-#{@otp_hash}"
  @base_url    "https://github.com/GenericJam/mob/releases/download/#{@release_tag}"

  @android_name "otp-android-#{@otp_hash}"
  @ios_sim_name "otp-ios-sim-#{@otp_hash}"

  @doc "Ensures the Android OTP release is cached. Returns {:ok, path} or {:error, reason}."
  @spec ensure_android() :: {:ok, String.t()} | {:error, term()}
  def ensure_android do
    ensure(@android_name, "#{@android_name}.tar.gz")
  end

  @doc "Ensures the iOS simulator OTP release is cached. Returns {:ok, path} or {:error, reason}."
  @spec ensure_ios_sim() :: {:ok, String.t()} | {:error, term()}
  def ensure_ios_sim do
    ensure(@ios_sim_name, "#{@ios_sim_name}.tar.gz")
  end

  @doc "Returns the cached Android OTP directory path (may not exist yet)."
  @spec android_otp_dir() :: String.t()
  def android_otp_dir, do: cache_dir(@android_name)

  @doc "Returns the cached iOS simulator OTP directory path (may not exist yet)."
  @spec ios_sim_otp_dir() :: String.t()
  def ios_sim_otp_dir, do: cache_dir(@ios_sim_name)

  # ── Private ──────────────────────────────────────────────────────────────────

  defp ensure(name, tarball) do
    dir = cache_dir(name)

    if valid_otp_dir?(dir) do
      {:ok, dir}
    else
      # Remove stale/incomplete directory before re-downloading.
      # This happens when a previous download attempt failed after mkdir
      # but before (or during) extraction — e.g. on Nix where curl may use
      # different CA certificates, or on a flaky network.
      if File.dir?(dir), do: File.rm_rf!(dir)
      download_and_extract(name, tarball, dir)
    end
  end

  # A valid extracted OTP dir must contain at least one erts-* subdirectory.
  defp valid_otp_dir?(dir) do
    File.dir?(dir) and Path.wildcard(Path.join(dir, "erts-*")) != []
  end

  defp cache_dir(name) do
    Path.join([System.get_env("HOME"), ".mob", "cache", name])
  end

  defp download_and_extract(name, tarball, dest_dir) do
    url      = "#{@base_url}/#{tarball}"
    tmp_file = Path.join(System.tmp_dir!(), tarball)

    IO.puts("  Downloading #{name} OTP release...")
    IO.puts("  URL: #{url}")

    File.mkdir_p!(Path.dirname(dest_dir))

    with :ok <- download(url, tmp_file),
         :ok <- extract(tmp_file, dest_dir),
         :ok <- verify_erts(dest_dir) do
      File.rm(tmp_file)
      IO.puts("  Cached at #{dest_dir}")
      {:ok, dest_dir}
    else
      {:error, reason} ->
        File.rm(tmp_file)
        File.rm_rf(dest_dir)
        {:error, reason}
    end
  end

  defp download(url, dest) do
    case System.cmd("curl", ["-L", "--fail", "--progress-bar", "-o", dest, url],
                    stderr_to_stdout: false) do
      {_, 0}    -> :ok
      {out, rc} -> {:error, "curl failed (exit #{rc}): #{String.trim(out)}"}
    end
  end

  defp extract(tarball, dest_dir) do
    File.mkdir_p!(dest_dir)
    # The tarball extracts into a single top-level directory; strip it with --strip-components=1.
    case System.cmd("tar", ["xzf", tarball, "-C", dest_dir, "--strip-components=1"],
                    stderr_to_stdout: true) do
      {_, 0}    -> :ok
      {out, rc} -> {:error, "tar failed (exit #{rc}): #{String.trim(out)}"}
    end
  end

  defp verify_erts(dir) do
    case Path.wildcard(Path.join(dir, "erts-*")) do
      [_ | _] -> :ok
      [] ->
        {:error,
         "OTP extraction produced no erts-* directory in #{dir}. " <>
         "The tarball may have an unexpected structure — please report this at " <>
         "https://github.com/GenericJam/mob/issues"}
    end
  end
end
