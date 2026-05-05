defmodule Mix.Tasks.Mob.Release.Android do
  use Mix.Task

  @shortdoc "Build a signed Android App Bundle (.aab) for Google Play"

  @moduledoc """
  Builds a release-signed Android App Bundle (.aab) ready to upload to Google Play.

      mix mob.release.android

  ## Output

  `android/app/build/outputs/bundle/release/app-release.aab`

  Use `mix mob.publish.android` to upload it to Google Play Console.

  ## Prerequisites

    1. Android signing config in `mob.exs`:

           config :mob_dev,
             android_signing: [
               store_file: "~/.android/keystore.jks",
               store_password: "your_store_password",
               key_alias: "your_key_alias",
               key_password: "your_key_password"
             ]

    2. A Google Play Developer account with your app registered

  ## What it does

    1. Downloads OTP runtimes for Android arm64 and arm32
    2. Copies ERTS helper executables into jniLibs
    3. Applies release signing configuration to Gradle
    4. Runs `gradle bundleRelease` to build the AAB
    5. Verifies the AAB was created successfully

  The generated AAB contains both arm64 and arm32 native libraries,
  plus the OTP runtime and compiled BEAM files.
  """

  @impl Mix.Task
  def run(_args) do
    unless File.dir?("android") do
      Mix.raise("No android/ directory found. Run from the root of a mob Android project.")
    end

    Mix.Task.run("compile")

    case MobDev.NativeBuild.build_all(platforms: [:android], release: true) do
      true ->
        aab_path = Path.expand("android/app/build/outputs/bundle/release/app-release.aab")

        if File.exists?(aab_path) do
          size = File.stat!(aab_path).size
          Mix.shell().info("")
          Mix.shell().info("#{green()}✓ Release build complete#{reset()}")
          Mix.shell().info("  AAB: #{cyan()}#{aab_path}#{reset()}")
          Mix.shell().info("  Size: #{format_size(size)}")
          Mix.shell().info("")
          Mix.shell().info("Next steps:")
          Mix.shell().info("  1. Test locally: #{cyan()}mix mob.deploy --android#{reset()}")

          Mix.shell().info(
            "  2. Upload to Google Play: #{cyan()}mix mob.publish.android#{reset()}"
          )
        else
          Mix.raise("AAB not found at #{aab_path}. Build may have failed.")
        end

      false ->
        Mix.raise("Android release build failed. See errors above.")
    end
  end

  def format_size(bytes) when bytes >= 1024 * 1024 do
    :io_lib.format("~.1fM", [bytes / (1024 * 1024)]) |> List.flatten() |> to_string()
  end

  def format_size(bytes) when bytes >= 1024 do
    :io_lib.format("~.1fK", [bytes / 1024]) |> List.flatten() |> to_string()
  end

  def format_size(bytes), do: "#{bytes}B"

  defp green, do: IO.ANSI.green()
  defp cyan, do: IO.ANSI.cyan()
  defp reset, do: IO.ANSI.reset()
end
