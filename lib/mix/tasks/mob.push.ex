defmodule Mix.Tasks.Mob.Push do
  use Mix.Task

  @shortdoc "Compile and hot-push changed modules to running mob devices"

  @moduledoc """
  Compiles the project and hot-pushes updated BEAM modules to all running
  Android and iOS devices — no app restart.

  The apps must already be running (start them with `mix mob.connect` or
  `mix mob.deploy` first). Modules are loaded into the live BEAM in place,
  equivalent to calling `nl(Module)` in IEx for each changed module.

  ## Options
    --all        Push all modules, not just those changed since last compile
    --cookie     Erlang cookie (default: mob_secret)
    --device     Target specific device by ID

  ## Examples
      mix mob.push
      mix mob.push --all
      mix mob.push --cookie my_cookie
      mix mob.push --device 5554
      mix mob.push --device R5CW3089HVB
  """

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [all: :boolean, cookie: :string, device: :string],
        aliases: [c: :cookie, d: :device]
      )

    push_all = Keyword.get(opts, :all, false)
    cookie = opts |> Keyword.get(:cookie, "mob_secret") |> String.to_atom()
    device_id = Keyword.get(opts, :device, nil)

    IO.puts("")

    snapshot = MobDev.HotPush.snapshot_beams()
    Mix.Task.run("compile")

    IO.puts("\n#{IO.ANSI.cyan()}Connecting to devices...#{IO.ANSI.reset()}")
    nodes = MobDev.HotPush.connect(cookie: cookie, device: device_id)

    if nodes == [] do
      IO.puts("#{IO.ANSI.yellow()}No running nodes found.#{IO.ANSI.reset()}")
      IO.puts("Start apps first: mix mob.connect")
    else
      IO.puts("  Connected: #{Enum.map_join(nodes, ", ", &to_string/1)}")
      IO.puts("#{IO.ANSI.cyan()}Pushing modules...#{IO.ANSI.reset()}")

      {pushed, failed} =
        if push_all,
          do: MobDev.HotPush.push_all(nodes),
          else: MobDev.HotPush.push_changed(nodes, snapshot)

      if pushed == 0 and failed == [] do
        IO.puts("  #{IO.ANSI.yellow()}Nothing changed.#{IO.ANSI.reset()}")
      else
        if pushed > 0 do
          IO.puts("  #{IO.ANSI.green()}✓ #{pushed} module(s) pushed#{IO.ANSI.reset()}")
        end

        Enum.each(failed, fn {mod, reason} ->
          IO.puts("  #{IO.ANSI.red()}✗ #{mod}: #{inspect(reason)}#{IO.ANSI.reset()}")
        end)
      end
    end
  end
end
