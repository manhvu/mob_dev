defmodule Mix.Tasks.Mob.Deploy do
  use Mix.Task

  @shortdoc "Build and deploy to all connected mob devices"

  @moduledoc """
  Compiles the project then pushes BEAM files to all connected
  Android devices and iOS simulators.

  ## Modes

  **Fast deploy** (default) — push BEAMs + restart. Use this for day-to-day
  Elixir code changes. Requires the native app already installed on device.

      mix mob.deploy

  **Full deploy** — build native binary + install APK/app + push BEAMs.
  Use this the first time, or after changes to native C/Java/Swift code.

      mix mob.deploy --native

  ## Options

    * `--native`      — build native binaries before pushing BEAMs
    * `--no-restart`  — push BEAMs but don't restart the app
  """

  @switches [native: :boolean, restart: :boolean, android: :boolean, ios: :boolean]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    restart   = Keyword.get(opts, :restart, true)
    native    = Keyword.get(opts, :native, false)
    platforms = resolve_platforms(opts)

    IO.puts("")

    if native do
      IO.puts("Fetching dependencies...")
      mix = System.find_executable("mix")
      System.cmd(mix, ["deps.get"], into: IO.stream())
    end

    Mix.Task.run("compile")
    IO.puts("\n#{IO.ANSI.cyan()}Deploying to devices...#{IO.ANSI.reset()}\n")

    if native do
      MobDev.NativeBuild.build_all(platforms: platforms)
    end

    {deployed, failed} = MobDev.Deployer.deploy_all(restart: restart, platforms: platforms)

    if deployed == [] and failed == [] do
      IO.puts("#{IO.ANSI.yellow()}No devices found.#{IO.ANSI.reset()}")
      IO.puts("Try: mix mob.devices   to diagnose connection issues")
    else
      if deployed != [] do
        IO.puts("\n#{IO.ANSI.green()}Deployed to #{length(deployed)} device(s)#{IO.ANSI.reset()}")
        if restart do
          IO.puts("Apps restarted. Run #{IO.ANSI.cyan()}mix mob.connect#{IO.ANSI.reset()} to open IEx.")
        else
          IO.puts("BEAMs pushed. In IEx: #{IO.ANSI.cyan()}nl(MyModule)#{IO.ANSI.reset()} to hot-load.")
        end
      end

      if failed != [] do
        IO.puts("\n#{IO.ANSI.red()}Failed on #{length(failed)} device(s)#{IO.ANSI.reset()}")
        Enum.each(failed, fn d ->
          IO.puts("  ✗ #{d.name || d.serial}: #{d.error}")
        end)
      end
    end
  end

  defp resolve_platforms(opts) do
    android = opts[:android]
    ios     = opts[:ios]

    cond do
      android && ios   -> [:android, :ios]
      android          -> [:android]
      ios              ->
        if macos?() do
          [:ios]
        else
          IO.puts("#{IO.ANSI.yellow()}Warning: --ios is only supported on macOS. Skipping iOS.#{IO.ANSI.reset()}")
          []
        end
      macos?()         -> [:android, :ios]
      true             -> [:android]
    end
  end

  defp macos?, do: match?({:unix, :darwin}, :os.type())
end
