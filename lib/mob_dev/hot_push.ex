defmodule MobDev.HotPush do
  @moduledoc """
  Connects to already-running device nodes and hot-pushes BEAM modules via RPC.

  Unlike `MobDev.Deployer`, this does NOT restart apps — modules are loaded
  into the running BEAM in place, just like `nl/1` in IEx.

  Requires apps to already be running (start with `mix mob.connect` or
  `mix mob.deploy` first).
  """

  alias MobDev.{Tunnel}
  alias MobDev.Discovery.{Android, IOS}

  @cookie :mob_secret

  @doc """
  Sets up adb tunnels (idempotent) and connects to all running device nodes.
  Returns list of connected node atoms.
  """
  @spec connect(keyword()) :: [node()]
  def connect(opts \\ []) do
    cookie = Keyword.get(opts, :cookie, @cookie)

    nodes =
      (Android.list_devices() ++ IOS.list_simulators())
      |> Enum.with_index()
      |> Enum.flat_map(fn {device, idx} ->
        case Tunnel.setup(device, idx) do
          {:ok, d} -> [d]
          _        -> []
        end
      end)
      |> Enum.flat_map(fn device ->
        ensure_local_dist(cookie)
        Node.set_cookie(device.node, cookie)
        case Node.connect(device.node) do
          true -> [device.node]
          _    -> []
        end
      end)

    nodes
  end

  @doc """
  Pushes all compiled BEAM files from `_build/dev/lib/*/ebin/` to `nodes`.
  Returns `{pushed_count, failed_list}`.
  """
  @spec push_all([node()]) :: {non_neg_integer(), list()}
  def push_all(nodes) do
    beams = Path.wildcard("_build/dev/lib/*/ebin/*.beam")
    push_beams(nodes, beams)
  end

  @doc """
  Takes a snapshot of current BEAM mtimes. Pass the result to `push_changed/2`
  before and after compiling to get only the modules that actually changed.
  """
  @spec snapshot_beams() :: %{String.t() => non_neg_integer()}
  def snapshot_beams do
    Path.wildcard("_build/dev/lib/*/ebin/*.beam")
    |> Map.new(fn path ->
      mtime = case File.stat(path, time: :posix) do
        {:ok, %{mtime: t}} -> t
        _ -> 0
      end
      {path, mtime}
    end)
  end

  @doc """
  Pushes BEAM files that changed since `snapshot` (from `snapshot_beams/0`).
  Returns `{pushed_count, failed_list}` — pushed_count is 0 if nothing changed.
  """
  @spec push_changed([node()], %{String.t() => non_neg_integer()}) :: {non_neg_integer(), list()}
  def push_changed(nodes, snapshot) do
    beams =
      Path.wildcard("_build/dev/lib/*/ebin/*.beam")
      |> Enum.filter(fn path ->
        current_mtime = case File.stat(path, time: :posix) do
          {:ok, %{mtime: t}} -> t
          _ -> 0
        end
        current_mtime != Map.get(snapshot, path, 0)
      end)

    push_beams(nodes, beams)
  end

  # ── Private ─────────────────────────────────────────────────────────────────

  defp push_beams(_nodes, []), do: {0, []}

  defp push_beams(nodes, beam_files) do
    results = Enum.map(beam_files, fn path ->
      module = beam_path_to_module(path)
      case File.read(path) do
        {:ok, binary} -> load_on_nodes(nodes, module, path, binary)
        {:error, reason} -> {:error, {module, reason}}
      end
    end)

    pushed  = Enum.count(results, &match?(:ok, &1))
    failed  = for {:error, pair} <- results, do: pair
    {pushed, failed}
  end

  defp load_on_nodes(nodes, module, path, binary) do
    fname = String.to_charlist(path)
    errors = Enum.flat_map(nodes, fn node ->
      case :rpc.call(node, :code, :load_binary, [module, fname, binary]) do
        {:module, ^module}       -> []
        {:error, :on_load_failure} -> []  # NIF modules already loaded — safe to ignore
        {:badrpc, reason}        -> [{node, reason}]
        {:error, reason}         -> [{node, reason}]
      end
    end)
    if errors == [], do: :ok, else: {:error, {module, errors}}
  end

  defp beam_path_to_module(path) do
    path |> Path.basename(".beam") |> String.to_atom()
  end

  defp ensure_local_dist(cookie) do
    unless Node.alive?() do
      Node.start(:"mob_dev@127.0.0.1", :longnames)
      Node.set_cookie(cookie)
    end
  end
end
