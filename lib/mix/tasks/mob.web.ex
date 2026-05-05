defmodule Mix.Tasks.Mob.Web do
  @moduledoc """
  Start the Mob Web UI - a comprehensive web interface for all mob_dev features.

  This task starts a Phoenix + Bandit web server that provides a unified
  dashboard for all mobile development tools including device management,
  deployment, emulators, provisioning, observer, and more.

      mix mob.web
      mix mob.web --port 4000   # default port
      mix mob.web --no-browser  # don't open browser automatically

  ## Features

  The web UI provides access to:

  - **Dashboard**: Device status, quick actions, system overview
  - **Devices**: Android and iOS device management
  - **Deploy**: Application deployment to devices
  - **Emulators**: Manage Android AVDs and iOS simulators
  - **Observer**: Remote node monitoring (web-based :observer)
  - **Provision**: Code signing and provisioning profile management
  - **Release**: Build and manage releases for Android and iOS
  - **Profiling**: Performance profiling and analysis
  - **CI Testing**: Continuous integration test management
  - **Logs**: Centralized log viewing and filtering
  - **Settings**: Configuration and preferences

  ## Options

  - `--port` / `-p`: Port to run the server on (default: 4000)
  - `--no-browser`: Don't open the browser automatically
  - `--node` / `-n`: Connect to a remote node
  - `--name`: Node name for distributed mode
  - `--cookie`: Cookie for distributed mode

  ## Examples

      mix mob.web
      mix mob.web --port 8080
      mix mob.web --no-browser
      mix mob.web --node other@host --name mynode
  """

  use Mix.Task

  @default_port 4000

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          port: :integer,
          browser: :boolean,
          node: :string,
          name: :string,
          cookie: :string
        ],
        aliases: [p: :port, n: :node]
      )

    port = Keyword.get(opts, :port, @default_port)
    open_browser? = Keyword.get(opts, :browser, true)
    target_node = Keyword.get(opts, :node, nil)
    node_name = Keyword.get(opts, :name, nil)
    cookie = Keyword.get(opts, :cookie, :erlang.get_cookie())

    # Setup distributed node if requested
    if node_name do
      {:ok, _} = Node.start(:"#{node_name}", :shortnames)
    end

    if cookie do
      Node.set_cookie(cookie |> to_string() |> String.to_atom())
    end

    if target_node do
      target = target_node |> to_string() |> String.to_atom()

      case Node.connect(target) do
        true -> Mix.shell().info("Connected to #{target}")
        false -> Mix.shell().error("Failed to connect to #{target}")
      end
    end

    # Configure the endpoint
    configure_endpoint(port)
    lan_ip = MobDev.Network.lan_ip()

    # Start required applications
    {:ok, _} = Application.ensure_all_started(:bandit)
    {:ok, _} = Application.ensure_all_started(:phoenix_live_view)
    {:ok, _} = Application.ensure_all_started(:phoenix_pubsub)

    # Start supervisor with all components
    children = [
      {Phoenix.PubSub, name: MobDev.PubSub},
      MobDev.Server.LogBuffer,
      MobDev.Server.ElixirLogBuffer,
      MobDev.Server.Endpoint,
      MobDev.Server.DevicePoller,
      MobDev.Server.LogStreamerSupervisor,
      MobDev.Server.WatchWorker,
      {Task.Supervisor, name: MobDev.Server.TaskSupervisor}
    ]

    {:ok, sup} =
      Supervisor.start_link(children, strategy: :one_for_one, name: MobDev.Server.Supervisor)

    # Attach the Elixir logger handler
    MobDev.Server.ElixirLogger.attach()

    # Print startup information
    local_url = "http://localhost:#{port}"
    IO.puts("")
    IO.puts("#{IO.ANSI.cyan()}=== Mob Web UI ===#{IO.ANSI.reset()}")
    IO.puts("  #{IO.ANSI.green()}#{local_url}#{IO.ANSI.reset()}")
    IO.puts("  #{IO.ANSI.cyan()}All mob_dev features available at:#{IO.ANSI.reset()}")
    IO.puts("    #{local_url}/dashboard")
    IO.puts("    #{local_url}/devices")
    IO.puts("    #{local_url}/deploy")
    IO.puts("    #{local_url}/emulators")
    IO.puts("    #{local_url}/observer")
    IO.puts("    #{local_url}/provision")
    IO.puts("    #{local_url}/release")
    IO.puts("    #{local_url}/profiling")
    IO.puts("    #{local_url}/ci")
    IO.puts("    #{local_url}/logs")

    if lan_ip do
      lan_url = "http://#{:inet.ntoa(lan_ip)}:#{port}"
      IO.puts("")
      IO.puts("  #{IO.ANSI.green()}LAN: #{lan_url}#{IO.ANSI.reset()}  ← open on phone")
      IO.puts("")
      IO.puts(MobDev.QR.render(lan_url))
    end

    IO.puts("")

    # Open browser if requested
    if open_browser? do
      open_browser(local_url)
    end

    if IEx.started?() do
      Process.unlink(sup)
      IO.puts("  #{IO.ANSI.green()}IEx ready.#{IO.ANSI.reset()}")
      IO.puts("")
    else
      IO.puts("  Press Ctrl+C to stop.")
      IO.puts("")
      Process.sleep(:infinity)
    end
  end

  defp configure_endpoint(port) do
    Application.put_env(:mob_dev, MobDev.Server.Endpoint,
      adapter: Bandit.PhoenixAdapter,
      http: [ip: {0, 0, 0, 0}, port: port],
      url: [host: "localhost", port: port],
      server: true,
      live_view: [signing_salt: "mob_dev_web_salt"],
      secret_key_base: String.duplicate("mob_dev_web_secret_key_base_not_for_production_", 2)
    )
  end

  defp open_browser(url) do
    cmd =
      case :os.type() do
        {:unix, :darwin} -> "open"
        {:unix, _} -> "xdg-open"
        {:win32, _} -> "start"
      end

    Task.start(fn ->
      :timer.sleep(500)
      System.cmd(cmd, [url], stderr_to_stdout: true)
    end)
  end
end
