defmodule Mix.Tasks.Dala.Debug do
  use Mix.Task

  @shortdoc "Interactive debugging for dala nodes"

  @moduledoc """
  Interactive debugging tools for remote Elixir nodes.

  ## Examples

      # Start interactive debug shell
      mix dala.debug

      # Inspect a process
      mix dala.debug --inspect MyApp.Worker

      # Evaluate code on remote node
      mix dala.debug --eval "MyApp.Config.get(:api_key)" --node dala_qa@192.168.1.5

      # Get memory report
      mix dala.debug --memory --node dala_qa@192.168.1.5

      # Get supervision tree
      mix dala.debug --tree --node dala_qa@192.168.1.5

  ## Options

    * `--inspect` - Process to inspect (module name or PID)
    * `--eval` - Code to evaluate on remote node
    * `--memory` - Show memory report
    * `--tree` - Show supervision tree
    * `--node` - Target node (default: local node)
    * `--trace` - Trace messages to/from a process
    * `--duration` - Trace duration in ms (default: 5000)
  """

  alias DalaDev.Debugger

  @impl Mix.Task
  def run(args) do
    {opts, _} =
      OptionParser.parse!(args,
        strict: [
          inspect: :string,
          eval: :string,
          memory: :boolean,
          tree: :boolean,
          node: :string,
          trace: :string,
          duration: :integer
        ],
        aliases: [
          i: :inspect,
          e: :eval,
          m: :memory,
          t: :tree,
          n: :node,
          d: :duration
        ]
      )

    node = resolve_node(Keyword.get(opts, :node))

    cond do
      Keyword.get(opts, :inspect) ->
        inspect_process(node, Keyword.get(opts, :inspect))

      Keyword.get(opts, :eval) ->
        eval_remote(node, Keyword.get(opts, :eval))

      Keyword.get(opts, :memory) ->
        show_memory_report(node)

      Keyword.get(opts, :tree) ->
        show_supervision_tree(node)

      Keyword.get(opts, :trace) ->
        trace_messages(node, Keyword.get(opts, :trace), opts)

      true ->
        start_interactive_shell(node)
    end
  end

  defp inspect_process(node, target_str) do
    target = parse_process_ref(target_str)

    Mix.shell().info("Inspecting #{target_str} on #{node}...")

    case Debugger.inspect_process(node, target) do
      {:ok, info} ->
        print_process_info(info)

      {:error, reason} ->
        Mix.shell().error("Failed to inspect process: #{inspect(reason)}")
    end
  end

  defp eval_remote(node, code) do
    Mix.shell().info("Evaluating on #{node}...")

    case Debugger.eval_remote(node, code) do
      {:ok, result} ->
        Mix.shell().info("Result:")
        IO.inspect(result)

      {:error, reason} ->
        Mix.shell().error("Failed to evaluate: #{inspect(reason)}")
    end
  end

  defp show_memory_report(node) do
    Mix.shell().info("Getting memory report for #{node}...")

    case Debugger.memory_report(node) do
      {:ok, report} ->
        print_memory_report(report)

      {:error, reason} ->
        Mix.shell().error("Failed to get memory report: #{inspect(reason)}")
    end
  end

  defp show_supervision_tree(node) do
    Mix.shell().info("Getting supervision tree for #{node}...")

    case Debugger.get_supervision_tree(node) do
      {:ok, tree} ->
        print_supervision_tree(tree)

      {:error, reason} ->
        Mix.shell().error("Failed to get supervision tree: #{inspect(reason)}")
    end
  end

  defp trace_messages(node, target_str, opts) do
    target = parse_process_ref(target_str)
    duration = Keyword.get(opts, :duration, 5000)

    Mix.shell().info("Tracing messages to/from #{target_str} for #{duration}ms...")

    case Debugger.trace_messages(node, target, duration: duration) do
      {:ok, messages} ->
        Mix.shell().info("Captured #{length(messages)} messages:")

        Enum.each(messages, fn msg ->
          print_trace_message(msg)
        end)

      {:error, reason} ->
        Mix.shell().error("Failed to trace messages: #{inspect(reason)}")
    end
  end

  defp start_interactive_shell(node) do
    Mix.shell().info("Starting interactive debug shell on #{node}...")
    Mix.shell().info("Type 'help' for commands, 'exit' to quit.")

    shell_loop(node)
  end

  defp shell_loop(node) do
    input = IO.gets("debug(#{node})> ") |> String.trim()

    case input do
      "help" ->
        print_help()
        shell_loop(node)

      "exit" ->
        :ok

      "node" ->
        Mix.shell().info("Current node: #{node}")
        shell_loop(node)

      "nodes" ->
        Mix.shell().info("Connected nodes: #{inspect(Node.list())}")
        shell_loop(node)

      "memory" ->
        show_memory_report(node)
        shell_loop(node)

      "tree" ->
        show_supervision_tree(node)
        shell_loop(node)

      "inspect " <> target ->
        inspect_process(node, target)
        shell_loop(node)

      "eval " <> code ->
        eval_remote(node, code)
        shell_loop(node)

      "" ->
        shell_loop(node)

      other ->
        Mix.shell().error("Unknown command: #{other}")
        Mix.shell().info("Type 'help' for available commands.")
        shell_loop(node)
    end
  end

  defp print_help do
    Mix.shell().info("""
    Available commands:
      help          - Show this help
      exit          - Exit debug shell
      node          - Show current node
      nodes         - List connected nodes
      memory        - Show memory report
      tree          - Show supervision tree
      inspect <target> - Inspect a process (module or PID)
      eval <code>  - Evaluate code on remote node
    """)
  end

  defp parse_process_ref(str) do
    case str do
      "self()" ->
        self()

      "self" ->
        self()

      str ->
        if String.starts_with?(str, ":") do
          String.to_atom(str)
        else
          String.to_existing_atom(str)
        end
    end
  rescue
    _ -> str
  end

  defp resolve_node(nil), do: Node.self()
  defp resolve_node(str) when is_binary(str), do: String.to_atom(str)
  defp resolve_node(node) when is_atom(node), do: node

  defp print_process_info(info) do
    Mix.shell().info("Process: #{info.pid}")
    Mix.shell().info("Status: #{info.status}")
    Mix.shell().info("Memory: #{info.memory} bytes")
    Mix.shell().info("Reductions: #{info.reductions}")
    Mix.shell().info("Message queue length: #{info.message_queue_len}")
    Mix.shell().info("Current function: #{info.current_function}")

    if info.dictionary != [] do
      Mix.shell().info("\nProcess dictionary:")

      Enum.each(info.dictionary, fn {k, v} ->
        Mix.shell().info("  #{k}: #{inspect(v)}")
      end)
    end

    if info.state do
      Mix.shell().info("\nState:")
      IO.inspect(info.state, pretty: true)
    end
  end

  defp print_memory_report(report) do
    Mix.shell().info("""
    Memory Report for #{report.node || "local"}:
      Total: #{report.total}
      Processes: #{report.processes}
      System: #{report.system}
      Atom: #{report.atom}
      Binary: #{report.binary}
      Code: #{report.code}
      ETS: #{report.ets}
    """)
  end

  defp print_supervision_tree(tree) do
    Mix.shell().info("Supervision Tree:")
    Mix.shell().info(Jason.encode!(tree, pretty: true))
  end

  defp print_trace_message(msg) do
    type_str =
      case msg.type do
        :send -> "SEND"
        :receive -> "RECV"
        _ -> "UNKNOWN"
      end

    Mix.shell().info("[#{type_str}] #{msg.message}")
  end
end
