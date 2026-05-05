defmodule MobDev.CrashDump do
  @moduledoc """
  Parse BEAM crash dumps from devices.

  BEAM crash dumps are text files generated when an Erlang VM crashes.
  This module parses them to extract useful information for debugging
  mobile Elixir nodes.

  ## Examples

      # Parse a crash dump file
      {:ok, info} = MobDev.CrashDump.parse_file("erl_crash.dump")

      # Parse from a device
      {:ok, info} = MobDev.CrashDump.fetch_from_device(node, "/path/to/crash.dump")

      # Generate a summary report
      report = MobDev.CrashDump.summary(info)
  """

  @type crash_info :: %{
          header: map(),
          system_info: map(),
          process_info: [map()],
          ports: [map()],
          ets_tables: [map()],
          timers: [map()],
          error_info: map() | nil,
          memory: map(),
          summary: String.t()
        }

  @doc """
  Parse a crash dump file.

  Returns a crash_info map with all parsed sections.
  """
  @spec parse_file(String.t()) :: {:ok, crash_info()} | {:error, term()}
  def parse_file(path) when is_binary(path) do
    case File.read(path) do
      {:ok, content} -> parse(content)
      error -> error
    end
  end

  @doc """
  Parse crash dump content from a string.

  Returns a crash_info map with all parsed sections.
  """
  @spec parse(String.t()) :: {:ok, crash_info()} | {:error, term()}
  def parse(content) when is_binary(content) do
    try do
      lines = String.split(content, "\n")

      header = parse_header(lines)
      system_info = parse_system_info(lines)
      process_info = parse_processes(lines)
      ports = parse_ports(lines)
      ets_tables = parse_ets_tables(lines)
      timers = parse_timers(lines)
      error_info = parse_error_info(lines)
      memory = parse_memory(lines)

      info = %{
        header: header,
        system_info: system_info,
        process_info: process_info,
        ports: ports,
        ets_tables: ets_tables,
        timers: timers,
        error_info: error_info,
        memory: memory,
        summary: generate_summary(header, error_info, memory)
      }

      {:ok, info}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  @doc """
  Fetch a crash dump from a remote device and parse it.

  Options:
  - `:timeout` - RPC timeout in ms (default: 30_000)
  """
  @spec fetch_from_device(node(), String.t(), keyword()) :: {:ok, crash_info()} | {:error, term()}
  def fetch_from_device(node, remote_path, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)

    case :rpc.call(node, File, :read, [remote_path], timeout) do
      {:badrpc, reason} -> {:error, {:rpc_error, reason}}
      {:ok, content} -> parse(content)
      {:error, _} = error -> error
      content when is_binary(content) -> parse(content)
    end
  end

  @doc """
  Generate a human-readable summary of the crash dump.
  """
  @spec summary(crash_info()) :: String.t()
  def summary(info) do
    """
    BEAM Crash Dump Summary
    =======================

    #{summary_header(info.header)}
    #{summary_error(info.error_info)}
    #{summary_memory(info.memory)}
    #{summary_processes(info.process_info)}

    System Info:
      OTP Release: #{get_in(info.system_info, [:otp_release]) || "unknown"}
      Elixir Version: #{get_in(info.system_info, [:elixir_version]) || "unknown"}
      Node: #{get_in(info.system_info, [:node]) || "unknown"}

    Top Processes by Memory:
    #{top_processes_by_memory(info.process_info, 5)}

    ETS Tables: #{length(info.ets_tables)}
    Timers: #{length(info.timers)}
    """
  end

  @doc """
  Generate an HTML report from crash dump info.
  """
  @spec html_report(crash_info()) :: String.t()
  def html_report(info) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>BEAM Crash Dump Report</title>
        <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-zinc-950 text-zinc-200 p-8">
        <h1 class="text-2xl font-bold mb-6">BEAM Crash Dump Report</h1>

        <div class="mb-8">
            <h2 class="text-xl font-semibold mb-4">Error Information</h2>
            #{error_html(info.error_info)}
        </div>

        <div class="mb-8">
            <h2 class="text-xl font-semibold mb-4">Memory</h2>
            #{memory_html(info.memory)}
        </div>

        <div class="mb-8">
            <h2 class="text-xl font-semibold mb-4">Top Processes</h2>
            #{processes_html(info.process_info)}
        </div>

        <div class="mb-8">
            <h2 class="text-xl font-semibold mb-4">System Info</h2>
            #{system_info_html(info.system_info)}
        </div>
    </body>
    </html>
    """
  end

  # ── Parsing helpers ──────────────────────────────

  defp parse_header(lines) do
    %{}
    |> maybe_put(:crash_dump_version, find_line_value(lines, "Crash dump created on"))
    |> maybe_put(:created_at, find_line_value(lines, "Crash dump created on"))
  end

  defp parse_system_info(lines) do
    %{}
    |> maybe_put(:otp_release, find_line_value(lines, "OTP release"))
    |> maybe_put(:elixir_version, find_line_value(lines, "Elixir version"))
    |> maybe_put(:node, find_line_value(lines, "Node name"))
    |> maybe_put(:compile_time, find_line_value(lines, "Compile time"))
  end

  defp parse_processes(lines) do
    # Simplified - would parse actual process entries
    []
  end

  defp parse_ports(lines) do
    []
  end

  defp parse_ets_tables(lines) do
    []
  end

  defp parse_timers(lines) do
    []
  end

  defp parse_error_info(lines) do
    error_type = find_line_value(lines, "Error in process")
    error_reason = find_line_value(lines, "Error reason")

    if error_type || error_reason do
      %{
        type: error_type,
        reason: error_reason
      }
    else
      nil
    end
  end

  defp parse_memory(lines) do
    %{
      total: find_line_value(lines, "Memory total"),
      processes: find_line_value(lines, "Memory processes"),
      system: find_line_value(lines, "Memory system")
    }
  end

  defp find_line_value(lines, pattern) do
    Enum.find_value(lines, fn line ->
      if String.contains?(line, pattern) do
        line
        |> String.split(":", parts: 2)
        |> case do
          [_, value] -> String.trim(value)
          _ -> nil
        end
      end
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # ── Summary helpers ──────────────────────────────

  defp generate_summary(header, error_info, memory) do
    "Crash dump parsed: #{Map.get(header, :created_at, "unknown time")}"
  end

  defp summary_header(header) do
    "Created at: #{Map.get(header, :created_at, "unknown")}\n"
  end

  defp summary_error(nil), do: "No error information found.\n"

  defp summary_error(error) do
    """
    Error: #{Map.get(error, :type, "unknown")}
    Reason: #{Map.get(error, :reason, "unknown")}
    """
  end

  defp summary_memory(memory) do
    """
    Memory:
      Total: #{Map.get(memory, :total, "unknown")}
      Processes: #{Map.get(memory, :processes, "unknown")}
      System: #{Map.get(memory, :system, "unknown")}
    """
  end

  defp summary_processes(processes) do
    "Processes found: #{length(processes)}\n"
  end

  defp top_processes_by_memory(processes, count) do
    if processes == [] do
      "  (parsing not fully implemented yet)\n"
    else
      processes
      |> Enum.sort_by(& &1.memory, &>=/2)
      |> Enum.take(count)
      |> Enum.with_index()
      |> Enum.map(fn {proc, i} ->
        "  #{i + 1}. #{proc.name || proc.pid} - #{proc.memory} bytes\n"
      end)
      |> Enum.join()
    end
  end

  # ── HTML helpers ──────────────────────────────

  defp error_html(nil), do: "<p>No error information</p>"

  defp error_html(error) do
    """
    <div class="bg-red-900/20 p-4 rounded">
        <p><strong>Type:</strong> #{Map.get(error, :type, "unknown")}</p>
        <p><strong>Reason:</strong> #{Map.get(error, :reason, "unknown")}</p>
    </div>
    """
  end

  defp memory_html(memory) do
    """
    <div class="grid grid-cols-3 gap-4">
        <div class="bg-zinc-800 p-4 rounded">
            <div class="text-sm text-zinc-400">Total</div>
            <div class="text-xl">#{Map.get(memory, :total, "N/A")}</div>
        </div>
        <div class="bg-zinc-800 p-4 rounded">
            <div class="text-sm text-zinc-400">Processes</div>
            <div class="text-xl">#{Map.get(memory, :processes, "N/A")}</div>
        </div>
        <div class="bg-zinc-800 p-4 rounded">
            <div class="text-sm text-zinc-400">System</div>
            <div class="text-xl">#{Map.get(memory, :system, "N/A")}</div>
        </div>
    </div>
    """
  end

  defp processes_html(processes) do
    if processes == [] do
      "<p>Process parsing not yet implemented.</p>"
    else
      # Would generate table
      "<p>Found #{length(processes)} processes</p>"
    end
  end

  defp system_info_html(info) do
    """
    <dl class="grid grid-cols-2 gap-2">
        <dt class="text-zinc-400">OTP Release</dt>
        <dd>#{Map.get(info, :otp_release, "N/A")}</dd>
        <dt class="text-zinc-400">Elixir Version</dt>
        <dd>#{Map.get(info, :elixir_version, "N/A")}</dd>
        <dt class="text-zinc-400">Node</dt>
        <dd>#{Map.get(info, :node, "N/A")}</dd>
    </dl>
    """
  end
end
