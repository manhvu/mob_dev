defmodule Mix.Tasks.Mob.Connect do
  use Mix.Task

  @shortdoc "Connect IEx to all running mob devices"

  @moduledoc """
  Discovers connected Android and iOS devices, sets up USB tunnels,
  restarts the app on each device, waits for Erlang nodes to come online,
  then drops into an IEx session connected to all of them.

      mix mob.connect

  Options:
    --no-iex     Set up connections but don't start IEx (print node names)
    --cookie     Erlang cookie (default: mob_secret)

  Examples:
      mix mob.connect
      mix mob.connect --no-iex
      mix mob.connect --cookie my_cookie
  """

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [iex: :boolean, cookie: :string],
      aliases:  [c: :cookie]
    )

    no_iex = Keyword.get(opts, :iex, true) == false
    cookie = opts |> Keyword.get(:cookie, "mob_secret") |> String.to_atom()

    Mix.Task.run("app.config")

    {connected, _failed} = MobDev.Connector.connect_all(cookie: cookie)

    if connected == [] do
      IO.puts("\n#{IO.ANSI.yellow()}No nodes connected. Nothing to do.#{IO.ANSI.reset()}\n")
      IO.puts("Try: mix mob.devices   to diagnose connection issues")
    else
      if no_iex do
        IO.puts("\nNodes ready:")
        Enum.each(connected, fn d -> IO.puts("  #{d.node}") end)
      else
        start_iex(connected, cookie)
      end
    end
  end

  defp start_iex(connected, cookie) do
    IO.puts("\n#{IO.ANSI.cyan()}Starting IEx (connected to #{length(connected)} device(s))...#{IO.ANSI.reset()}")
    IO.puts("  Node.list()       — see connected nodes")
    IO.puts("  nl(MyModule)      — hot-push code to all nodes")
    IO.puts("")

    # Start distribution on the local node and connect to all devices.
    unless Node.alive?() do
      Node.start(:"mob_dev@127.0.0.1", :longnames)
      Node.set_cookie(cookie)
    end

    Enum.each(connected, fn d ->
      Node.set_cookie(d.node, cookie)
      Node.connect(d.node)
    end)

    # Hand off to IEx in this process — tunnels stay alive via adb daemon.
    IEx.start()
  end
end
