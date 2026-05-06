# Remote Debugging and Tracing Guide

## Overview

The `DalaDev.Remote` module provides an easy-to-use interface for debugging and tracing remote nodes in a dala Elixir cluster. It eliminates the need to manually handle RPC calls or node selection.

## Quick Start

### 1. Select a Node

```elixir
# Select a specific node
iex> DalaDev.Remote.select_node(:"dala_demo@127.0.0.1")
:ok

# List available nodes
iex> DalaDev.Remote.nodes()
["dala_demo@127.0.0.1", "dala_qa@192.168.1.5"]

# Get currently selected node
iex> DalaDev.Remote.selected_node()
{:ok, :"dala_demo@127.0.0.1"}
```

### 2. Automatic Node Selection

If only one remote node is available, it will be automatically selected:

```elixir
iex> DalaDev.Remote.auto_select()
{:ok, :"dala_demo@127.0.0.1"}
```

If multiple nodes are available, you must explicitly select one:

```elixir
iex> DalaDev.Remote.auto_select()
{:error, {:multiple_nodes, [:"node1@host", :"node2@host"],
         "Please select a node using DalaDev.Remote.select_node/1"}}
```

### 3. Set Timeout

The default timeout for all remote operations is 5000ms (5 seconds). You can change this:

```elixir
iex> DalaDev.Remote.set_timeout(10_000)
:ok

iex> DalaDev.Remote.get_timeout()
10000
```

## Usage Examples

### Observer - Inspect Node State

```elixir
# Observe a node (returns comprehensive system information)
iex> DalaDev.Remote.Observer.observe()
{:ok, 
  %{node: :"dala_demo@127.0.0.1",
    timestamp: ~U[2023-01-01 12:00:00Z],
    system: %{memory: %{total: 1024, ...}, ...},
    processes: [%{pid: "#PID<0.123.0>", memory: 1024, ...}],
    ets_tables: [...],
    ...
  }
}

# Get just system information
iex> DalaDev.Remote.Observer.system_info()
%{memory: %{total: 1024, processes: 45, ...}, ...}

# Get process list
iex> DalaDev.Remote.Observer.process_list()
[%{pid: "#PID<0.123.0>", memory: 1024, ...}]

# Get ETS tables
iex> DalaDev.Remote.Observer.ets_tables()
[%{id: "#Ref<0.123.456>", name: "my_table", size: 100, ...}]
```

### Debugger - Inspect and Control

```elixir
# Get memory report
iex> DalaDev.Remote.Debugger.memory_report()
{:ok, 
  %{total: "1.2 GB",
    processes: "45 MB",
    system: "256 MB",
    atom: "2.1 MB",
    binary: "128 MB",
    code: "5.6 MB",
    ets: "16 MB"
  }
}

# Inspect a process
iex> DalaDev.Remote.Debugger.inspect_process(:my_worker)
{:ok,
  %{pid: "#PID<0.123.0>",
    dictionary: ["my_key: my_value"],
    message_queue_len: 0,
    memory: 1024,
    reductions: 1500,
    status: :waiting,
    current_function: "my_module.my_function/2",
    state: "%MyState{...}"
  }
}

# Evaluate code on remote node
iex> DalaDev.Remote.Debugger.eval("1 + 1")
{:ok, 2}

iex> DalaDev.Remote.Debugger.eval("Enum.map(1..3, &(&1 * 2))")
{:ok, [2, 4, 6]}

iex> DalaDev.Remote.Debugger.eval("MyApp.Config.get(:api_key)")
{:ok, "secret_key"}

# Evaluate with bindings
iex> DalaDev.Remote.Debugger.eval("x + y", bindings: [x: 10, y: 20])
{:ok, 30}

# Trace messages to/from a process
iex> DalaDev.Remote.Debugger.trace_messages(:my_worker, duration: 5000)
{:ok,
  [%{type: :send, message: "hello", to: "#PID<0.456.0>"},
   %{type: :receive, message: "world"}]
}

# Get supervision tree
iex> DalaDev.Remote.Debugger.supervision_tree()
{:ok,
  %{pid: "#PID<0.123.0>",
    children: [...]
  }
}
```

### LogCollector - Collect Logs

```elixir
# Collect logs from selected node
iex> DalaDev.Remote.LogCollector.collect_logs(last: 100, level: :info)
{:ok,
  [%{ts: ~U[2023-01-01 12:00:00Z],
     node: :"dala_demo@127.0.0.1",
     level: :info,
     message: "Application started",
     metadata: []},
   ...
  ]
}

# Collect Android logs
iex> DalaDev.Remote.LogCollector.collect_android_logs("emulator-5554", lines: 50)
{:ok, "01-01 12:00:00.123  1234  5678 I MyApp: Message"}
```

### Rpc - Generic Remote Calls

```elixir
# Call any function on remote node
iex> DalaDev.Remote.Rpc.call(MyModule, :my_function, [arg1, arg2])
{:ok, result}

# Call with no arguments
iex> DalaDev.Remote.Rpc.call(MyModule, :get_status, [])
{:ok, :online}

# Call with custom timeout
iex> DalaDev.Remote.Rpc.call(MyModule, :slow_function, [], timeout: 30_000)
{:ok, result}

# Handle errors
iex> DalaDev.Remote.Rpc.call(MyModule, :nonexistent, [])
{:error, :undef}
```

## Node Selection Strategies

### Strategy 1: Explicit Selection

```elixir
# List available nodes
nodes = DalaDev.Remote.nodes()

# Select the one you want
DalaDev.Remote.select_node(hd(nodes))
```

### Strategy 2: Automatic Selection

```elixir
# Automatically select if only one node is available
case DalaDev.Remote.auto_select() do
  {:ok, node} ->
    IO.puts("Auto-selected: #{node}")
  {:error, {:multiple_nodes, nodes, _msg}} ->
    IO.puts("Multiple nodes available: #{inspect(nodes)}")
    # Select one explicitly
    DalaDev.Remote.select_node(hd(nodes))
  {:error, :no_remote_nodes} ->
    IO.puts("No remote nodes available")
end
```

### Strategy 3: Pattern Matching

```elixir
# Select node based on pattern
nodes = DalaDev.Remote.nodes()

case Enum.find(nodes, &String.contains?(to_string(&1), "prod")) do
  nil -> DalaDev.Remote.select_node(hd(nodes))
  prod_node -> DalaDev.Remote.select_node(prod_node)
end
```

## Error Handling

All functions return `{:ok, result}` on success or `{:error, reason}` on failure:

```elixir
case DalaDev.Remote.Observer.observe() do
  {:ok, data} ->
    # Process data
    IO.inspect(data.system.memory)

  {:error, :no_node_selected} ->
    IO.puts("Please select a node first")

  {:error, :node_not_found} ->
    IO.puts("Selected node not found")

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
```

## Common Patterns

### Pattern 1: Inspect Multiple Nodes

```elixir
# Inspect all available nodes
for node <- DalaDev.Remote.nodes() do
  DalaDev.Remote.select_node(node)
  {:ok, data} = DalaDev.Remote.Observer.observe()
  IO.puts("#{node}: #{length(data.processes)} processes")
end
```

### Pattern 2: Compare Node States

```elixir
# Compare memory usage across nodes
memory_by_node =
  for node <- DalaDev.Remote.nodes() do
    DalaDev.Remote.select_node(node)
    {:ok, report} = DalaDev.Remote.Debugger.memory_report()
    {node, report.total}
  end

IO.inspect(memory_by_node)
```

### Pattern 3: Execute on All Nodes

```elixir
# Execute code on all nodes
results =
  for node <- DalaDev.Remote.nodes() do
    DalaDev.Remote.select_node(node)
    DalaDev.Remote.Debugger.eval("Node.self()")
  end

IO.inspect(results)
```

### Pattern 4: Monitor Node Health

```elixir
# Check if nodes are responsive
health_check =
  for node <- DalaDev.Remote.nodes() do
    DalaDev.Remote.select_node(node)
    
    case DalaDev.Remote.Debugger.memory_report() do
      {:ok, _} -> {node, :healthy}
      {:error, _} -> {node, :unhealthy}
    end
  end

IO.inspect(health_check)
```

## Integration with Mix Tasks

You can use the Remote module in your own mix tasks:

```elixir
defmodule Mix.Tasks.MyTask do
  use Mix.Task

  def run(_) do
    # Select a node
    DalaDev.Remote.select_node(:"my_node@127.0.0.1")

    # Get system info
    {:ok, data} = DalaDev.Remote.Observer.observe()

    # Do something with the data
    IO.inspect(data)
  end
end
```

## Best Practices

1. **Always check return values**: All functions return `{:ok, result}` or `{:error, reason}`

2. **Set appropriate timeouts**: Increase timeout for slow operations

3. **Handle node selection errors**: Check if node selection succeeded

4. **Clean up after yourself**: Clear selection when done

5. **Use pattern matching**: Handle different error cases explicitly

## Troubleshooting

### Issue: "no_node_selected" error

**Solution**: Select a node first
```elixir
DalaDev.Remote.select_node(:"my_node@127.0.0.1")
```

### Issue: "node_not_found" error

**Solution**: Check available nodes
```elixir
DalaDev.Remote.nodes()
```

### Issue: RPC timeout

**Solution**: Increase timeout
```elixir
DalaDev.Remote.set_timeout(30_000)
```

### Issue: Cannot inspect current process

**Solution**: The current process cannot be inspected due to `:sys.get_state` limitation. Inspect a different process instead.

## See Also

- [Observer Module Documentation](https://hexdocs.pm/dala_dev/DalaDev.Observer.html)
- [Debugger Module Documentation](https://hexdocs.pm/dala_dev/DalaDev.Debugger.html)
- [LogCollector Module Documentation](https://hexdocs.pm/dala_dev/DalaDev.LogCollector.html)
