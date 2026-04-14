defmodule Mix.Tasks.Mob.Server do
  use Mix.Task

  @shortdoc "Start the Mob dev server (localhost:4040)"

  @moduledoc """
  Starts the Mob dev server and opens it in the browser.

      mix mob.server
      mix mob.server --port 4040   # default port

  The server provides:
  - Live device status cards (Android + iOS simulator)
  - Per-device deploy buttons ("Update" and "First Deploy")
  - Streaming log panel (logcat / iOS simulator console)

  The server runs until you press Ctrl+C.
  """

  @default_port 4040

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [port: :integer])
    port = opts[:port] || @default_port
    lan_ip = MobDev.Network.lan_ip()

    configure_endpoint(port, lan_ip)
    {:ok, _} = Application.ensure_all_started(:bandit)
    {:ok, _} = Application.ensure_all_started(:phoenix_live_view)

    children = [
      {Phoenix.PubSub,                  name: MobDev.PubSub},
      MobDev.Server.LogBuffer,
      MobDev.Server.Endpoint,
      MobDev.Server.DevicePoller,
      MobDev.Server.LogStreamerSupervisor,
      {Task.Supervisor,                  name: MobDev.Server.TaskSupervisor}
    ]

    {:ok, _sup} = Supervisor.start_link(children, strategy: :one_for_one, name: MobDev.Server.Supervisor)

    local_url = "http://localhost:#{port}"
    IO.puts("")
    IO.puts("#{IO.ANSI.cyan()}=== Mob Dev Server ===#{ IO.ANSI.reset()}")
    IO.puts("  #{IO.ANSI.green()}#{local_url}#{IO.ANSI.reset()}")

    if lan_ip do
      lan_url = "http://#{:inet.ntoa(lan_ip)}:#{port}"
      IO.puts("  #{IO.ANSI.green()}#{lan_url}#{IO.ANSI.reset()}  ← open on phone")
      IO.puts("")
      IO.puts(MobDev.QR.render(lan_url))
    end

    IO.puts("")
    IO.puts("  Press Ctrl+C to stop.")
    IO.puts("")

    open_browser(local_url)
    Process.sleep(:infinity)
  end

  defp configure_endpoint(port, lan_ip) do
    lan_url = if lan_ip, do: "http://#{:inet.ntoa(lan_ip)}:#{port}", else: nil
    Application.put_env(:mob_dev, :dashboard_lan_url, lan_url)

    Application.put_env(:mob_dev, MobDev.Server.Endpoint,
      adapter:  Bandit.PhoenixAdapter,
      http: [ip: {0, 0, 0, 0}, port: port],
      url:  [host: "localhost", port: port],
      server: true,
      live_view: [signing_salt: "mob_dev_server_salt"],
      secret_key_base: String.duplicate("mob_dev_secret_key_base_not_for_production_", 2)
    )
  end

  defp open_browser(url) do
    cmd = case :os.type() do
      {:unix, :darwin} -> "open"
      {:unix, _}       -> "xdg-open"
      {:win32, _}      -> "start"
    end

    Task.start(fn ->
      :timer.sleep(500)   # brief pause so the server is up before the browser hits it
      System.cmd(cmd, [url], stderr_to_stdout: true)
    end)
  end
end
