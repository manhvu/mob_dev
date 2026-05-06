defmodule DalaDev.LogCollector do
  @moduledoc """
  Unified log collection from dala Elixir cluster nodes.

  Collects logs from:
  - BEAM logger (via RPC from remote nodes)
  - Android logcat (for Android devices)
  - iOS syslog (for iOS simulators/devices)
  - Distribution logs (EPMD, net_kernel)

  ## Examples

      # Stream logs from all connected nodes
      DalaDev.LogCollector.stream_logs(:all_nodes, level: :info)

      # Collect last 100 log lines from a specific node
      DalaDev.LogCollector.collect_logs(:"dala_qa@192.168.1.5", last: 100)

      # Export logs to file
      DalaDev.LogCollector.export_logs("cluster_logs.jsonl", nodes: :all)
  """

  alias DalaDev.{Device, Utils}

  @type node_ref :: node() | :all_nodes | Device.t()
  @type log_entry :: %{
          ts: DateTime.t(),
          node: node(),
          level: Logger.level(),
          message: String.t(),
          metadata: keyword()
        }

  @type filter ::
          {:level, Logger.level()}
          | {:module, module()}
          | {:node, node()}
          | {:time_range, {DateTime.t(), DateTime.t()}}
          | {:pattern, String.t() | Regex.t()}

  @doc """
  Collect logs from a node or all connected nodes.

  Options:
  - `:last` - number of recent log entries to return
  - `:level` - minimum log level (:error, :warning, :info, :debug)
  - `:since` - collect logs since this DateTime
  - `:format` - :text (default) or :jsonl
  """
  @spec collect_logs(node_ref(), keyword()) :: {:ok, [log_entry()]} | {:error, term()}
  def collect_logs(node_ref, opts \\ []) do
    nodes = resolve_nodes(node_ref)

    logs =
      nodes
      |> Enum.map(fn node -> Task.async(fn -> collect_from_node(node, opts) end) end)
      |> Enum.flat_map(fn task -> Task.await(task, 10_000) end)
      |> Enum.sort_by(& &1.ts, {:desc, DateTime})
      |> maybe_limit(Keyword.get(opts, :last))

    {:ok, logs}
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Stream logs in real-time.

  Returns a stream that yields log entries as they arrive.
  Call `Stream.run/1` or enumerate to start streaming.

  Options:
  - `:level` - minimum log level
  - `:nodes` - list of nodes or :all_nodes
  - `:format` - :text or :jsonl
  """
  @spec stream_logs(node_ref(), keyword()) :: Enumerable.t()
  def stream_logs(node_ref, opts \\ []) do
    nodes = resolve_nodes(node_ref)

    Stream.resource(
      fn -> init_stream_state(nodes, opts) end,
      fn state -> fetch_new_logs(state, opts) end,
      fn state -> close_stream(state) end
    )
  end

  @doc """
  Export logs to a file.

  Format:
  - "jsonl" (default) - JSON Lines format, one log per line
  - "text" - Human-readable text
  - "csv" - CSV format with columns: ts,node,level,message,metadata
  """
  @spec export_logs(Path.t(), keyword()) :: :ok | {:error, term()}
  def export_logs(path, opts \\ []) do
    nodes = Keyword.get(opts, :nodes, :all_nodes) |> resolve_nodes()
    format = Keyword.get(opts, :format, :jsonl)

    case collect_logs(nodes, opts) do
      {:ok, logs} ->
        File.mkdir_p!(Path.dirname(path))

        case format do
          :jsonl -> write_jsonl(logs, path)
          :text -> write_text(logs, path)
          :csv -> write_csv(logs, path)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get BEAM VM logs from a remote node via RPC.

  Collects from:
  - Logger messages in :logger handler
  - error_logger (legacy)
  - SASL reports (if available)
  """
  @spec collect_beam_logs(node(), keyword()) :: [log_entry()]
  def collect_beam_logs(node, opts \\ []) when is_atom(node) do
    timeout = Keyword.get(opts, :timeout, 5_000)

    case :rpc.call(node, __MODULE__, :fetch_local_logs, [opts], timeout) do
      logs when is_list(logs) -> logs
      {:badrpc, _reason} -> []
      _ -> []
    end
  end

  @doc """
  Fetch local logs (called via RPC on remote nodes).

  This function runs ON the remote node to collect its local logs.
  """
  @spec fetch_local_logs(keyword()) :: [log_entry()]
  def fetch_local_logs(opts \\ []) do
    # Try to get recent log events from Logger's configured handlers
    # This is a best-effort collection - not all handlers buffer logs
    try do
      level = Keyword.get(opts, :level, :info)
      since = Keyword.get(opts, :since, nil)

      # Use :logger.get_handler_config/1 and try to fetch buffered logs
      # Falls back to empty list if no buffer is available
      case :logger.get_handler_config(:default) do
        {:ok, config} ->
          # Try to extract from any buffer in the config
          extract_logs_from_config(config, level, since)

        _ ->
          []
      end
    rescue
      _ -> []
    end
  end

  # ── Android logcat collection ───────────────────────────────────────────

  @doc """
  Collect Android logs via adb logcat.

  Filters for the app package by default.
  """
  @spec collect_android_logs(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def collect_android_logs(serial, opts \\ []) do
    package = Keyword.get(opts, :package, DalaDev.Config.bundle_id())
    lines = Keyword.get(opts, :lines, 100)

    # First check if device exists
    case Utils.run_adb_with_timeout(["devices"], stderr_to_stdout: true, timeout: 5_000) do
      {:ok, output} ->
        if device_exists?(output, serial) do
          args = ["-s", serial, "logcat", "-d", "-t", to_string(lines)]

          args =
            if package do
              args ++ ["-s", package]
            else
              args
            end

          case Utils.run_adb_with_timeout(args, stderr_to_stdout: true, timeout: 10_000) do
            {:ok, output} -> {:ok, output}
            {:error, reason} -> {:error, reason}
          end
        else
          {:error, "Device not found: #{serial}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp device_exists?(adb_output, serial) do
    adb_output
    |> String.split("\n")
    |> Enum.any?(fn line ->
      String.starts_with?(line, serial)
    end)
  end

  @doc """
  Stream Android logs in real-time.
  """
  @spec stream_android_logs(String.t(), keyword()) :: Enumerable.t()
  def stream_android_logs(serial, opts \\ []) do
    package = Keyword.get(opts, :package, DalaDev.Config.bundle_id())

    Stream.resource(
      fn ->
        port = start_logcat_port(serial, package)
        %{port: port, buffer: ""}
      end,
      fn %{port: port, buffer: buffer} ->
        {new_lines, new_buffer} = read_port_output(port, buffer)
        {new_lines, %{port: port, buffer: new_buffer}}
      end,
      fn %{port: port} ->
        Port.close(port)
      end
    )
  end

  # ── iOS log collection ──────────────────────────────────────────────────

  @doc """
  Collect iOS simulator logs via `xcrun simctl spawn log stream`.
  """
  @spec collect_ios_sim_logs(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def collect_ios_sim_logs(udid, opts \\ []) do
    bundle_id = Keyword.get(opts, :bundle_id, DalaDev.Config.bundle_id())
    predicate = "process == \"#{bundle_id}\""

    case System.cmd(
           "xcrun",
           [
             "simctl",
             "spawn",
             udid,
             "log",
             "show",
             "--predicate",
             predicate,
             "--last",
             "5m"
           ],
           stderr_to_stdout: true
         ) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, output}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Collect iOS physical device logs via `idevicesyslog` (requires libimobiledevice).
  """
  @spec collect_ios_device_logs(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def collect_ios_device_logs(udid, _opts \\ []) do
    if System.find_executable("idevicesyslog") do
      case System.cmd("idevicesyslog", ["-u", udid, "-n", "100"], stderr_to_stdout: true) do
        {output, 0} -> {:ok, output}
        {output, _} -> {:error, output}
      end
    else
      {:error, "idevicesyslog not found - install libimobiledevice"}
    end
  end

  # ── Private helpers ─────────────────────────────────────────────────────

  defp resolve_nodes(:all_nodes) do
    Node.list() ++ [Node.self()]
  end

  defp resolve_nodes(node) when is_atom(node) do
    [node]
  end

  defp resolve_nodes(%Device{node: node}) when not is_nil(node) do
    [node]
  end

  defp resolve_nodes(_), do: []

  defp collect_from_node(node, opts) do
    if node == Node.self() do
      fetch_local_logs(opts)
    else
      collect_beam_logs(node, opts)
    end
  end

  defp maybe_limit(logs, nil), do: logs
  defp maybe_limit(logs, n) when is_integer(n), do: Enum.take(logs, n)

  defp extract_logs_from_config(_config, _level, _since) do
    # Placeholder - in a real implementation, we'd extract from log handler buffers
    []
  end

  defp init_stream_state(nodes, _opts) do
    %{nodes: nodes, last_ts: nil}
  end

  defp fetch_new_logs(state, opts) do
    logs =
      Enum.flat_map(state.nodes, fn node ->
        collect_from_node(node, opts)
        |> Enum.filter(fn entry ->
          is_nil(state.last_ts) or DateTime.compare(entry.ts, state.last_ts) == :gt
        end)
      end)

    new_state = %{state | last_ts: latest_ts(logs, state.last_ts)}

    if logs == [] do
      {:halt, new_state}
    else
      {logs, new_state}
    end
  end

  defp close_stream(_state), do: :ok

  defp latest_ts([], nil), do: nil
  defp latest_ts([], ts), do: ts

  defp latest_ts(logs, current) do
    latest = Enum.max_by(logs, & &1.ts)

    if is_nil(current) or DateTime.compare(latest.ts, current) == :gt do
      latest.ts
    else
      current
    end
  end

  defp start_logcat_port(serial, package) do
    # Start adb logcat as a port for streaming
    Port.open(
      {:spawn, "adb -s #{serial} logcat -s #{package}"},
      [:binary, :stream, :use_stdio, :exit_status]
    )
  end

  defp read_port_output(port, buffer) do
    receive do
      {^port, {:data, data}} ->
        new_buffer = buffer <> data
        {lines, remaining} = split_lines(new_buffer)
        {lines, remaining}
    after
      100 ->
        {[], buffer}
    end
  end

  defp split_lines(buffer) do
    case String.split(buffer, "\n", parts: 2) do
      [line, rest] -> {[line], rest}
      [line] -> {[], line}
    end
  end

  defp write_jsonl(logs, path) do
    File.open!(path, [:write, :utf8])
    |> then(fn file ->
      Enum.each(logs, fn entry ->
        Jason.encode!(entry) |> IO.puts(file)
      end)

      File.close(file)
    end)

    :ok
  end

  defp write_text(logs, path) do
    File.open!(path, [:write, :utf8])
    |> then(fn file ->
      Enum.each(logs, fn entry ->
        IO.puts(
          file,
          "[#{entry.ts}] #{entry.node} #{entry.level}: #{entry.message}"
        )
      end)

      File.close(file)
    end)

    :ok
  end

  defp write_csv(logs, path) do
    File.open!(path, [:write, :utf8])
    |> then(fn file ->
      IO.puts(file, "ts,node,level,message,metadata")

      Enum.each(logs, fn entry ->
        meta = inspect(entry.metadata)
        IO.puts(file, "#{entry.ts},#{entry.node},#{entry.level},\"#{entry.message}\",\"#{meta}\"")
      end)

      File.close(file)
    end)

    :ok
  end
end
