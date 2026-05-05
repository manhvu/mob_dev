# Dala Observer - Remote Node Monitoring

## Overview

The `DalaDev.Observer` module provides a web-based alternative to Erlang's `:observer.start()` for monitoring remote Elixir nodes. It collects comprehensive system information via RPC calls and displays them in separated LiveView pages with a dashboard for navigation.

## Features

- **Dashboard**: Overview with summary cards and navigation to all specialized views
- **System Information**: Memory usage, uptime, system version, process count, ETS tables count, word size
- **Process List**: View all processes with memory, reductions, message queue length, current function, and status. Sort by memory/reductions/queue, filter by name/PID
- **ETS Tables**: Browse ETS tables with their types, sizes, memory usage, and ownership info
- **Applications**: List all running applications with versions
- **Modules**: View loaded modules and their memory consumption
- **Ports**: Monitor port activity (I/O, connected processes)
- **System Load**: View scheduler usage and I/O statistics with visual progress bars
- **Tracing**: Start/stop process tracing and message flow analysis
- **Remote Node Support**: Connect to and monitor any reachable Erlang node
- **Real-time Updates**: Auto-refreshes every 5 seconds
- **Responsive Design**: Mobile-friendly web UI

## Quick Start

### Starting the Observer Web Interface

```bash
# Start on default port 4000, monitor local node
mix dala.observer

# Start on custom port
mix dala.observer --port 8080

# Connect to and monitor a remote node
mix dala.observer --node other@192.168.1.100

# Run as a named distributed node
mix dala.observer --name observer@localhost --cookie mycookie
```

The observer will be available at: `http://localhost:PORT/observer`

### Using the Observer Module Directly

```elixir
alias DalaDev.Observer

# Observe local node
{:ok, data} = Observer.observe(Node.self())

# Observe remote node (will connect via RPC)
{:ok, data} = Observer.observe(:"remote@192.168.1.100")

# Get specific information
system = Observer.system_info(Node.self())
processes = Observer.process_list(Node.self())
ets_tables = Observer.ets_tables(Node.self())
```

## Web Interface Pages

### 1. Dashboard (`/observer/:node`)
- Summary cards (processes, ETS tables, memory, uptime)
- Navigation cards to all specialized views
- Node selector dropdown

### 2. System Info (`/observer/:node/system`)
- Basic information (version, uptime, word size, process count, ETS tables)
- Memory usage breakdown with visual progress bars
- Statistics (runtime)

### 3. Processes (`/observer/:node/processes`)
- Sortable table (click headers to sort by PID, memory, reductions, message queue)
- Toggle sort order (ascending/descending)
- Filter by PID, name, or current function
- Click on process row to view details modal
- Shows top 100 processes by default

### 4. ETS Tables (`/observer/:node/ets`)
- Sortable table (by memory or size)
- Filter by name or ID
- Click on table row to view details modal
- Shows table type, owner, heir, protection

### 5. Applications (`/observer/:node/applications`)
- Grid view of all running applications
- Shows name, description, and version

### 6. Modules (`/observer/:node/modules`)
- Summary (total modules count, total memory)
- Table of all loaded modules with paths

### 7. Ports (`/observer/:node/ports`)
- Table of all active ports
- Shows I/O statistics (input/output)
- Connected process and OS PID

### 8. System Load (`/observer/:node/load`)
- Scheduler usage with visual progress bars
- I/O statistics (input/output bytes)

### 9. Tracing (`/observer/:node/tracing`)
- View and manage active traces
- Start traces from the Processes page
- Stop traces with one click

## API Functions

All functions are public for testing and extensibility:

- `Observer.observe/2` - Get comprehensive node data
- `Observer.system_info/2` - Get system-level information
- `Observer.process_list/2` - Get process list sorted by memory
- `Observer.ets_tables/2` - Get ETS tables sorted by memory

## File Structure

### New Files
- `lib/dala_dev/observer.ex` - Core Observer module
- `lib/dala_dev/server/live/observer_live.ex` - Dashboard LiveView
- `lib/dala_dev/server/live/observer/system.ex` - System Info LiveView
- `lib/dala_dev/server/live/observer/processes.ex` - Processes LiveView
- `lib/dala_dev/server/live/observer/ets.ex` - ETS Tables LiveView
- `lib/dala_dev/server/live/observer/applications.ex` - Applications LiveView
- `lib/dala_dev/server/live/observer/modules.ex` - Modules LiveView
- `lib/dala_dev/server/live/observer/ports.ex` - Ports LiveView
- `lib/dala_dev/server/live/observer/load.ex` - System Load LiveView
- `lib/dala_dev/server/live/observer/tracing.ex` - Tracing LiveView
- `lib/mix/tasks/dala.observer.ex` - Mix task to start observer
- `test/dala_dev/observer_test.exs` - Test suite

### Modified Files
- `lib/dala_dev/server/router.ex` - Added routes for all Observer pages
- `AGENTS.md` - Documented new public API

## Usage Examples

### Monitor a Mobile Device Node

```bash
# Assuming your mobile node is running with name 'myphone@192.168.1.50'
mix dala.observer --node myphone@192.168.1.50
```

Then open `http://localhost:4000/observer` in your browser to see:
- Dashboard with summary and navigation
- Click on "System Info" to see memory usage of the mobile device
- Click on "Processes" to see all running processes on the device
- Click on "ETS Tables" to browse ETS tables, etc.

### Programmatic Access

```elixir
# In IEx or your application
alias DalaDev.Observer

# Get all data from a remote node
{:ok, data} = Observer.observe(:"device@192.168.1.100")

# Access specific parts
system = data[:system]
processes = data[:processes]
ets_tables = data[:ets_tables]

# Get just system info
info = Observer.system_info(:"device@192.168.1.100")
IO.inspect(info[:memory][:total], label: "Total memory")
```

## Dependencies

The following dependencies were already present in `mix.exs`:

- `phoenix_live_view ~> 1.0` - LiveView rendering
- `bandit ~> 1.0` - HTTP server
- `phoenix_pubsub ~> 2.0` - PubSub for LiveView
- `plug_crypto ~> 2.0` - Crypto utilities

No new dependencies were required - the project already had all necessary packages!

## Testing

Tests are located at `test/dala_dev/observer_test.exs` and cover:

- Local node observation
- System info structure validation
- Process list validation
- ETS tables validation
- Applications list validation
- Modules info validation
- Ports info validation
- Load info validation
- Remote node error handling

Run tests with:

```bash
mix test test/dala_dev/observer_test.exs
mix test --exclude integration  # All tests (517 tests, 0 failures)
```

## Comparison to :observer.start()

| Feature | :observer.start() | DalaDev.Observer |
|---------|-------------------|------------------|
| Platform | Local GUI (wxWidgets) | Web browser |
| Remote nodes | Limited | Full support via RPC |
| Real-time updates | Yes | Yes (auto-refresh every 5s) |
| Process sorting | Yes | Yes (memory, reductions, queue) |
| ETS browsing | Yes | Yes (with details modal) |
| Applications | Yes | Yes |
| Load charts | Yes | Yes (scheduler % with bars) |
| Mobile-friendly | No | Yes (responsive web UI) |
| Tracing | Yes | Yes (start/stop from UI) |
| Modules view | Yes | Yes |
| Ports view | Yes | Yes |

## Notes

- The observer connects to remote nodes via `Node.connect/1` and uses `:rpc.call/4` to collect data
- All data collection happens in the `DalaDev.Observer.call_remote/2` helper
- Each LiveView page auto-refreshes every 5 seconds
- Process and ETS table lists are limited to top 100 by memory usage in the UI
- Error handling is included for unreachable nodes
- The dashboard provides quick navigation to all specialized views
- All pages have a "Back to Dashboard" link for easy navigation
