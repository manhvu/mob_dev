defmodule DalaDev.ObserverTest do
  use ExUnit.Case, async: false
  doctest DalaDev.Observer

  alias DalaDev.Observer

  describe "observe/2" do
    test "returns system info for local node" do
      assert {:ok, data} = Observer.observe(Node.self())
      assert data[:node] == Node.self()
      assert data[:system] != nil
      assert data[:system][:memory] != nil
      assert data[:system][:process_count] != nil
      assert data[:timestamp] != nil
    end

    test "returns process list" do
      assert {:ok, data} = Observer.observe(Node.self())
      assert is_list(data[:processes])
      assert length(data[:processes]) > 0

      # Check process info structure
      if length(data[:processes]) > 0 do
        proc = List.first(data[:processes])
        assert Map.has_key?(proc, :pid)
        assert Map.has_key?(proc, :memory)
        assert Map.has_key?(proc, :reductions)
        assert Map.has_key?(proc, :message_queue_len)
        assert Map.has_key?(proc, :current_function)
        assert Map.has_key?(proc, :status)
      end
    end

    test "returns ETS tables" do
      assert {:ok, data} = Observer.observe(Node.self())
      assert is_list(data[:ets_tables])

      # Check ETS table structure
      if length(data[:ets_tables]) > 0 do
        table = List.first(data[:ets_tables])
        assert Map.has_key?(table, :id)
        assert Map.has_key?(table, :name)
        assert Map.has_key?(table, :type)
        assert Map.has_key?(table, :size)
        assert Map.has_key?(table, :memory)
      end
    end

    test "returns applications list" do
      assert {:ok, data} = Observer.observe(Node.self())
      assert is_list(data[:applications])
      assert length(data[:applications]) > 0

      # Check application structure
      app = List.first(data[:applications])
      assert Map.has_key?(app, :name)
      assert Map.has_key?(app, :description)
      assert Map.has_key?(app, :version)
    end

    test "returns modules info" do
      assert {:ok, data} = Observer.observe(Node.self())
      assert data[:modules] != nil
      assert Map.has_key?(data[:modules], :count)
      assert Map.has_key?(data[:modules], :total_memory)
    end

    test "returns ports info" do
      assert {:ok, data} = Observer.observe(Node.self())
      assert is_list(data[:ports])

      # Check port structure if any ports exist
      if length(data[:ports]) > 0 do
        port = List.first(data[:ports])
        assert Map.has_key?(port, :id)
        assert Map.has_key?(port, :name)
      end
    end

    test "returns load info" do
      assert {:ok, data} = Observer.observe(Node.self())
      assert data[:load] != nil
      assert Map.has_key?(data[:load], :io)
    end
  end

  describe "system_info/2" do
    test "returns system information" do
      info = Observer.system_info(Node.self())
      assert info[:memory] != nil
      assert info[:system_version] != nil
      assert info[:uptime_ms] != nil
      assert info[:process_count] != nil
      assert info[:ets_tables_count] != nil
    end
  end

  describe "process_list/2" do
    test "returns list of processes" do
      processes = Observer.process_list(Node.self())
      assert is_list(processes)
      assert length(processes) > 0
    end

    test "processes are sorted by memory descending" do
      processes = Observer.process_list(Node.self())
      memories = Enum.map(processes, & &1.memory)
      assert memories == Enum.sort(memories, &(&1 >= &2))
    end
  end

  describe "ets_tables/2" do
    test "returns list of ETS tables" do
      tables = Observer.ets_tables(Node.self())
      assert is_list(tables)
    end

    test "ETS tables are sorted by memory descending" do
      tables = Observer.ets_tables(Node.self())

      if length(tables) > 1 do
        memories = Enum.map(tables, & &1.memory)
        assert memories == Enum.sort(memories, &(&1 >= &2))
      end
    end
  end

  describe "remote node observation" do
    test "handles unreachable node gracefully" do
      # Try to observe a non-existent node
      result = Observer.observe(:"non_existent_node@127.0.0.1")
      # Should either fail with error or return error in data
      case result do
        {:error, _reason} -> :ok
        {:ok, _} -> :ok
        other -> flunk("Expected error but got: #{inspect(other)}")
      end
    end
  end
end
