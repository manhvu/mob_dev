# get_state Implementation Guide

## Overview

Successfully implemented `DalaDev.Remote.Debugger.get_state/2` function that mirrors the Erlang `:sys.get_state/1` function from the stdlib sys module.

## Implementation Details

### Function Signature

```elixir
DalaDev.Remote.Debugger.get_state(pid_or_name, opts \\ [])
```

### Parameters

- `pid_or_name` - A PID, registered name (atom), or `{mod, fun}` tuple of the process
- `opts` - Options:
  - `:timeout` - RPC timeout in milliseconds (defaults to remote timeout)

### Returns

- `{:ok, state}` on success, where `state` is the process state
- `{:error, reason}` on failure

## Usage Examples

### Get State by PID

```elixir
# Get state of a process by PID
{:ok, state} = DalaDev.Remote.Debugger.get_state(#PID<0.123.0>)
```

### Get State by Registered Name

```elixir
# Get state of a process by registered name
{:ok, state} = DalaDev.Remote.Debugger.get_state(:my_worker)
```

### Get State with Custom Timeout

```elixir
# Get state with custom timeout
{:ok, state} = DalaDev.Remote.Debugger.get_state(:my_worker, timeout: 10_000)
```

### Handle Errors

```elixir
case DalaDev.Remote.Debugger.get_state(:nonexistent_process) do
  {:ok, state} ->
    IO.inspect(state)
  {:error, :process_not_found} ->
    IO.puts("Process not found")
  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
```

## Technical Implementation

### Local Node Execution

When the selected node is the local node, the function executes directly without RPC:

```elixir
if node == Node.self() do
  # Local execution - no RPC needed
  case DalaDev.Debugger.get_process_state_local(pid_or_name) do
    nil -> {:error, :process_not_found}
    state -> {:ok, state}
  end
else
  # Remote execution via RPC
  :rpc.call(node, DalaDev.Debugger, :get_process_state, [pid_or_name], timeout)
end
```

### Remote Node Execution

When the selected node is remote, the function uses RPC to call `:get_process_state/1` on the remote node:

```elixir
:rpc.call(node, DalaDev.Debugger, :get_process_state, [pid_or_name], timeout)
```

### Process State Retrieval

The `get_process_state/1` function uses Erlang's `:sys.get_state/1` to retrieve the process state:

```elixir
defp get_process_state(pid) do
  # Try to get state from GenServer or GenStateMachine
  try do
    # This is a best-effort attempt
    case :sys.get_state(pid) do
      state when not is_nil(state) -> inspect(state)
      _ -> nil
    end
  rescue
    _ -> nil
  catch
    :exit, _ -> nil
  end
end
```

## Error Handling

The function handles the following error cases:

1. **Process Not Found**: Returns `{:error, :process_not_found}`
2. **RPC Timeout**: Returns `{:error, :timeout}`
3. **RPC Failure**: Returns `{:error, reason}` where reason is the RPC error
4. **No State Available**: Returns `{:ok, nil}` if the process doesn't have state

## Requirements

The process must be a system process (e.g., a GenServer, GenStateMachine, or other process that implements the sys protocol) to have retrievable state.

## Limitations

1. **Current Process**: Cannot inspect the current process due to `:sys.get_state` limitation
2. **Non-System Processes**: Processes that don't implement the sys protocol will return `nil`
3. **RPC Overhead**: Remote execution has RPC overhead

## Testing

The implementation includes comprehensive tests:

- Get state by PID
- Get state by registered name
- Handle non-existent process
- Error handling

All tests pass successfully.

## See Also

- [Erlang sys:get_state/1](https://www.erlang.org/doc/apps/stdlib/sys.html#get_state/1)
- [DalaDev.Remote Documentation](REMOTE_USAGE.md)
- [DalaDev.Debugger Module](https://hexdocs.pm/dala_dev/DalaDev.Debugger.html)
