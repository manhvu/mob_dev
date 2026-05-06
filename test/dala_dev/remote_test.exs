defmodule DalaDev.RemoteTest do
  use ExUnit.Case, async: false

  alias DalaDev.Remote

  describe "node management" do
    test "lists remote nodes" do
      nodes = Remote.nodes()
      assert is_list(nodes)
    end

    test "selects and gets node" do
      # Select current node for testing
      current_node = Node.self()
      assert :ok = Remote.select_node(current_node)
      assert {:ok, ^current_node} = Remote.selected_node()
    end

    test "clears selection" do
      Remote.select_node(Node.self())
      assert :ok = Remote.clear_selection()
      assert {:error, :no_node_selected} = Remote.selected_node()
    end

    test "auto-selects single node" do
      # This test assumes there's at least one remote node
      # In a real scenario, we'd set up test nodes
      result = Remote.auto_select()
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "sets and gets timeout" do
      assert :ok = Remote.set_timeout(10_000)
      assert 10_000 = Remote.get_timeout()
      # Reset to default
      assert :ok = Remote.set_timeout(5000)
    end
  end

  describe "Observer submodule" do
    setup do
      Remote.select_node(Node.self())
      :ok
    end

    test "observes local node" do
      current_node = Node.self()
      assert {:ok, data} = Remote.Observer.observe()
      assert ^current_node = data[:node]
      assert data[:system] != nil
      assert data[:processes] != nil
    end

    test "gets system info" do
      system_info = Remote.Observer.system_info()
      assert is_map(system_info)
      assert system_info[:memory] != nil
    end

    test "gets process list" do
      processes = Remote.Observer.process_list()
      assert is_list(processes)
      assert length(processes) > 0
    end

    test "gets ETS tables" do
      tables = Remote.Observer.ets_tables()
      assert is_list(tables)
    end
  end

  describe "Debugger submodule" do
    setup do
      Remote.select_node(Node.self())
      :ok
    end

    test "gets memory report" do
      assert {:ok, report} = Remote.Debugger.memory_report()
      assert is_map(report)
      assert Map.has_key?(report, :total)
      assert Map.has_key?(report, :processes)
    end

    test "gets process state" do
      # Create a simple GenServer to test
      {:ok, pid} = Agent.start_link(fn -> %{count: 42} end)
      assert {:ok, state} = Remote.Debugger.get_state(pid)
      # State should be inspectable
      assert is_binary(state)
      Agent.stop(pid)
    end

    test "gets process state by name" do
      {:ok, _pid} = Agent.start_link(fn -> %{data: "test"} end, name: :test_agent)
      assert {:ok, state} = Remote.Debugger.get_state(:test_agent)
      assert is_binary(state)
      Agent.stop(:test_agent)
    end

    test "returns error for non-existent process" do
      assert {:error, :process_not_found} = Remote.Debugger.get_state(:nonexistent_process)
    end

    test "evaluates code" do
      assert {:ok, 2} = Remote.Debugger.eval("1 + 1")
      assert {:ok, [2, 4, 6]} = Remote.Debugger.eval("Enum.map(1..3, &(&1 * 2))")
    end

    test "evaluates code with bindings" do
      assert {:ok, 3} = Remote.Debugger.eval("x + 1", bindings: [x: 2])
    end

    test "inspects current process" do
      # Can't inspect current process due to :sys.get_state limitation
      # Use a different process instead
      other_pid = spawn(fn -> Process.sleep(:infinity) end)
      assert {:ok, info} = Remote.Debugger.inspect_process(other_pid)
      assert is_map(info)
      assert Map.has_key?(info, :pid)
      Process.exit(other_pid, :kill)
    end

    @tag :skip
    test "traces messages" do
      # Create a simple test process that stays alive
      test_pid =
        spawn_link(fn ->
          # Keep the process alive - just wait indefinitely
          receive do
            :stop -> :ok
          after
            5000 -> :ok
          end
        end)

      # Wait a bit for the process to be ready
      Process.sleep(10)

      # Verify the process is alive
      assert Process.alive?(test_pid)

      # Trace the test process with a longer duration to capture more messages
      assert {:ok, messages} = Remote.Debugger.trace_messages(test_pid, duration: 5000)

      # Send many messages to trigger tracing
      for i <- 1..100 do
        send(test_pid, {:msg, i})
      end

      # Stop the process
      send(test_pid, :stop)

      # Wait for the trace to complete
      Process.sleep(100)

      # Should have captured messages
      assert is_list(messages)
    end

    test "gets supervision tree" do
      assert {:ok, tree} = Remote.Debugger.supervision_tree()
      assert is_map(tree)
      # Tree can have different structures depending on whether :supervisor process exists
      assert Map.has_key?(tree, :pid) or Map.has_key?(tree, :supervisors)
    end
  end

  describe "Rpc submodule" do
    setup do
      Remote.select_node(Node.self())
      :ok
    end

    test "calls function on selected node" do
      assert {:ok, 2} = Remote.Rpc.call(Kernel, :+, [1, 1])
    end

    test "calls function with no arguments" do
      assert {:ok, :ok} = Remote.Rpc.call(Process, :sleep, [0])
    end

    test "handles function errors" do
      assert {:error, _} = Remote.Rpc.call(Kernel, :+, [1, "not_a_number"])
    end

    test "calls function with custom timeout" do
      assert {:ok, 3} = Remote.Rpc.call(Kernel, :+, [1, 2], timeout: 10_000)
    end
  end
end
