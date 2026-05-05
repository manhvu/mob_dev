# Mobile Elixir Cluster Development Tools

This document provides a comprehensive overview of the complete toolkit for developing Elixir applications that join a cluster from mobile devices (Android/iOS).

## Current Capabilities (mob_dev v0.3.28+)

### ✅ Available Tools

#### Device Management
- **`mix mob.devices`** - List all connected Android/iOS devices with status
  - Shows device type (physical/simulator), platform, status, and node name
  - Supports `--format json` for programmatic parsing
- **`mix mob.emulators`** - Manage AVDs and iOS simulators
  - List available emulators/simulators
  - Start/stop simulator instances
  - Create new AVDs with specific API levels
- **`MobDev.Discovery.Android`** - Android device discovery via adb
  - `parse_devices_output/1` - Public parser for testability
  - Handles both physical devices and emulators
- **`MobDev.Discovery.IOS`** - iOS discovery (simulator + physical)
  - `parse_simctl_json/1`, `parse_simctl_text/1` - Public parsers
  - `parse_runtime_version/1` - Version string parser
  - Supports both simctl and devicectl for physical devices
- **`MobDev.Device`** - Unified device struct
  - Fields: `id`, `name`, `platform`, `type`, `status`, `node_name`
  - Helper functions: `short_id/1`, `node_name/1`, `match_id?/2`

#### Cluster Connection
- **`mix mob.connect`** - Connect IEx to all running mob devices
  - Sets up tunnels, restarts app, waits for node, connects IEx
  - `--name` flag for multiple simultaneous sessions
  - `--no-iex` flag to print node names without connecting
- **`MobDev.Connector`** - Orchestrates the full connection flow
  - Discovery → Tunnel setup → App restart → Wait for node → Connect
- **`MobDev.Tunnel`** - Manages port tunnels for Erlang distribution
  - Android: `adb forward`/`reverse` for TCP tunneling
  - iOS Simulator: Direct TCP (same machine)
  - iOS Physical: `iproxy` for USB tunneling
  - `dist_port/1` - Returns the distribution port for a device

#### Code Deployment
- **`mix mob.deploy`** - Build and deploy to all connected devices
  - `--device <id>` - Deploy to specific device by ID or short ID
  - `--native` - Also build and install native APK/iOS app
  - `--beam-flags` - Set BEAM flags (persisted to `mob.exs`)
  - Hot-push via RPC when possible, falls back to native push + restart
- **`mix mob.push`** - Hot-push only changed modules (no restart)
  - Uses `nl(Module)` via RPC to load new modules in running BEAM
  - Compares BEAM checksums to determine changed modules
- **`mix mob.watch`** - Auto hot-push on file changes
  - File system watcher that triggers `mix mob.push` on save
  - Can be controlled from dashboard or via `MobDev.Server.WatchWorker`
- **`MobDev.Deployer`** - Full deployment logic (BEAM + native)
  - Handles both first deploy and updates
  - Platform-specific build and install steps
- **`MobDev.HotPush`** - Connects and hot-pushes via RPC
  - `snapshot_beams/0` - Get checksums of all loaded BEAMs
  - `push_changed/2` - Push only changed modules

#### Build & Release
- **`mix mob.install`** - First-run setup for new projects
  - Downloads OTP runtime via `MobDev.OtpDownloader`
  - Generates app icons via `MobDev.IconGenerator`
  - Creates `mob.exs` configuration file
- **`mix mob.icon`** - Generate app icons
  - `--source PATH` - Source image (default: `assets/static/icon.png`)
  - Generates all required sizes for Android and iOS
- **`mix mob.provision`** - iOS provisioning profiles
  - Manages certificates and provisioning profiles
  - `diagnose_xcodebuild_failure/1` - Translates xcodebuild errors to actionable hints
- **`mix mob.release`** - Build signed iOS .ipa
  - Handles code signing and archive creation
- **`mix mob.publish`** - Upload to TestFlight
  - Wraps `xcrun altool` for App Store Connect upload
- **`MobDev.NativeBuild`** - Build APK/.app bundles
  - `narrow_platforms_for_device/2` - Single source of truth for platform narrowing
  - `ios_toolchain_available?/0` - Check Xcode toolchain
  - `read_sdk_dir/1` - Read Android SDK directory
- **`MobDev.OtpDownloader`** - Download pre-built OTP runtimes
  - `ensure_android/1`, `ensure_ios_sim/0`, `ensure_ios_device/0`
  - `valid_otp_dir?/2` - Schema validation (bump this, not hash)
  - `ios_device_extras_present?/1` - Check for required iOS device patches

#### Development Server
- **`mix mob.server`** - Start dev dashboard at `localhost:4040`
  - Device cards with live status, deploy/update buttons
  - Live log streaming (device logs + Elixir Logger)
  - Text filtering with comma-separated terms
  - Watch mode toggle for auto-deploy
  - QR code for opening dashboard on device
- **`mix mob.gen.live_screen`** - Generate LiveView + Mob.Screen pair
  - Scaffolds a LiveView that renders on both web and mobile
- **`MobDev.Enable`** - Enable optional features
  - LiveView integration, additional Mob features

#### Diagnostics
- **`mix mob.doctor`** - Check environment and configuration
  - Verifies adb, xcode tools, OTP runtimes, project setup
  - Reports issues with actionable fix suggestions
- **`mix mob.cache`** - Manage machine-wide caches
  - Clear OTP download cache
  - Show cache locations and sizes
- **`MobDev.Network`** - Network utilities
  - EPMD health checks
  - Node connectivity tests

#### Navigation Validation
- **`mix mob.routes`** - Validate navigation destinations
  - Analyzes `push_screen`, `reset_to`, `pop_to` in `lib/**/*.ex`
  - AST-based analysis with `Code.ensure_loaded/1` verification
  - `--strict` flag for CI (exit non-zero on warnings)

#### Battery Benchmarking
- **`mix mob.battery_bench_ios`** / **`mix mob.battery_bench_android`**
  - Measures BEAM idle power draw on mobile devices
  - Multi-source state probing (battery level, screen state, app state, RPC reachability)
  - CSV logging to `_build/bench/run_<ts>.csv`
  - Post-run analysis with success rate, reconnect count, time-by-state
  - Presets: `nerves` (tuned), `untuned`, `sbwt`
- **`MobDev.Bench.Probe`** - Multi-source state probing
- **`MobDev.Bench.Logger`** - CSV logging
- **`MobDev.Bench.Summary`** - Post-run analysis with taint warnings
- **`MobDev.Bench.Preflight`** - Pre-run checklist (device ready, app running, etc.)
- **`MobDev.Bench.Reconnector`** - Auto-reconnect logic for flapping connections
- **`MobDev.Bench.DeviceObserver`** - Subscribe to device events

---

## New Tools Added (This Session)

### 🆕 Log Collection & Streaming

#### MobDev.LogCollector (`lib/mob_dev/log_collector.ex`)
Unified log collection from mobile Elixir cluster nodes.

**Features:**
- Collect logs from BEAM nodes via RPC (`:rpc.call/4` to `:logger.get_all/0`)
- Android logcat integration (`adb logcat -s <tag>`)
- iOS simulator syslog via `xcrun simctl spawn --type=system log stream`
- iOS physical device logs via `idevicesyslog`
- Multiple output formats: text, JSONL, CSV
- Real-time streaming with filtering by level, module, node
- Log rotation and size limits

**Key Functions:**
```elixir
MobDev.LogCollector.collect_logs(:all_nodes, level: :info)
MobDev.LogCollector.stream_logs(node, follow: true, level: :error)
MobDev.LogCollector.export_logs("logs.jsonl", nodes: :all_nodes, format: :jsonl)
MobDev.LogCollector.tail_logs(node, lines: 100)
```

**Implementation Details:**
- Uses `MobDev.Utils.compile_regex/2` for all regex (never `Regex.compile!`)
- Graceful degradation when tools are missing
- Public API for testing: `parse_log_line/1`, `filter_by_level/2`

#### mix mob.logs (`lib/mix/tasks/mob.logs.ex`)
```bash
mix mob.logs                          # Stream all logs
mix mob.logs --node mob_qa@192.168.1.5  # Specific node
mix mob.logs --level error            # Filter by level
mix mob.logs --save logs.jsonl       # Save to file
mix mob.logs --follow                # Continuous streaming
mix mob.logs --format jsonl          # JSONL output
mix mob.logs --tail 100              # Last 100 lines
```

---

### 🆕 Screen Capture & Recording

#### MobDev.ScreenCapture (`lib/mob_dev/screen_capture.ex`)
Capture screenshots, record video, and live preview from mobile devices.

**Features:**
- Android: `adb screencap` / `screenrecord` (max 3 min per recording)
- iOS Simulator: `xcrun simctl io screenshot/recordVideo`
- iOS Physical: `idevicescreenshot` / `idevicerecord` (libimobiledevice)
- Live preview via WebSocket (integration with `mob.server` dashboard)
- Configurable format (PNG, JPEG), scale, bitrate, time limit
- Batch capture for time-lapse sequences

**Key Functions:**
```elixir
MobDev.ScreenCapture.capture(device, save_as: "screen.png", format: :png)
MobDev.ScreenCapture.record(device, duration: 30, output: "video.mp4")
MobDev.ScreenCapture.live_preview(device, port: 5050)
MobDev.ScreenCapture.list_devices()  # Show available devices with capture support
```

**Implementation Details:**
- Detects available tools at runtime (adb, xcrun, libimobiledevice)
- Returns `{:error, reason}` tuples with actionable error messages
- Public parsers for testing device output formats

#### mix mob.screen (`lib/mix/tasks/mob.screen.ex`)
```bash
mix mob.screen --capture                 # Take screenshot
mix mob.screen --capture screenshot.png  # Save to file
mix mob.screen --record --duration 30   # Record video (30 seconds)
mix mob.screen --preview                # Live preview on port 5050
mix mob.screen --list                   # List devices with capture support
mix mob.screen --format jpeg            # JPEG format (smaller files)
```

---

### 🆕 Distributed Tracing

#### MobDev.Tracing (`lib/mob_dev/tracing.ex`)
Distributed tracing for mobile Elixir clusters.

**Features:**
- Trace function calls across nodes via `:erlang.trace/3`
- Message send/receive tracing
- Process spawn/exit tracking
- Export to Chrome Tracing format (chrome://tracing)
- Per-module and per-PID tracing
- Trace sessions with unique IDs for concurrent traces

**Key Functions:**
```elixir
{:ok, trace_id} = MobDev.Tracing.start_trace(:all_nodes, modules: [MyApp])
MobDev.Tracing.get_events(trace_id)
MobDev.Tracing.export_chrome_trace(trace_id, "trace.json")
MobDev.Tracing.trace_call(node, MyModule, :my_func, [arg1])
MobDev.Tracing.stop_trace(trace_id)
```

**Implementation Details:**
- Uses Erlang's built-in tracing (`:erlang.trace/3`, `:erlang.trace_pattern/3`)
- Collects traces via `:erlang.get_tracer/0` and `:erlang.trace_info/2`
- Formats output for Chrome Tracing JSON schema
- Public API: `parse_trace_event/1` for testing

---

## Recommended Additional Tools (Not Yet Implemented)

### 🔮 Benchmarking Module

#### MobDev.Benchmark (Proposed)
Runtime benchmarking for mobile nodes.

**Features Needed:**
- Measure execution time, memory, reductions via `:timer.tc/1`, `:erlang.memory/0`
- Compare performance across devices (normalize by CPU frequency)
- Cluster-wide benchmarks with aggregated results
- HTML/Markdown report generation with charts
- Integration with `MobDev.Bench.Probe` for system state during benchmarks

**Proposed API:**
```elixir
MobDev.Benchmark.measure(node, fn -> MyApp.heavy_computation() end)
MobDev.Benchmark.compare([node1, node2], test_module: MyBench)
MobDev.Benchmark.memory_profile(node, duration: 60_000)
MobDev.Benchmark.cluster_bench(modules: [MyApp, MyAppWeb])
```

#### mix mob.bench (Proposed)
```bash
mix mob.bench                         # Run standard benchmarks
mix mob.bench --test my_test.exs     # Custom benchmark
mix mob.bench --compare node1,node2  # Compare nodes
mix mob.bench --report report.html   # Generate report
```

---

### 🔮 Advanced Debugging

#### MobDev.Debugger (Proposed)
Enhanced debugging tools for remote nodes.

**Features Needed:**
- Process inspection (state via `:sys.get_state/1`, mailbox via `:erlang.process_info/2`)
- Trace specific processes with `:dbg` or `:redbug`
- Remote code evaluation via `:rpc.call/4`
- LiveView/Supervisor state tree visualization
- Memory breakdown reports (ETS, binaries, process heap)

**Proposed API:**
```elixir
MobDev.Debugger.inspect_process(node, pid_or_name)
MobDev.Debugger.get_supervision_tree(node)
MobDev.Debugger.eval_remote(node, "MyModule.state()")
MobDev.Debugger.trace_messages(pid, duration: 5000)
MobDev.Debugger.memory_breakdown(node)
```

#### mix mob.debug (Proposed)
```bash
mix mob.debug                         # Interactive debug shell
mix mob.debug --inspect pid          # Inspect process
mix mob.debug --eval "MyModule.test()"  # Remote evaluation
mix mob.debug --memory               # Memory report
```

---

### 🔮 Network Diagnostics

#### MobDev.NetworkDiag (Proposed)
Cluster connectivity diagnostics.

**Features Needed:**
- Node ping and latency measurement via `:net_adm.ping/1`, `:rpc.call/4`
- EPMD health checks (port 4369 reachability)
- Distribution diagnostics (cookie mismatch, firewall issues)
- Packet loss detection with timestamped probes

**Proposed API:**
```elixir
MobDev.NetworkDiag.ping_node(node)
MobDev.NetworkDiag.measure_latency(node, samples: 100)
MobDev.NetworkDiag.check_epmd_health(node)
MobDev.NetworkDiag.trace_distribution(node)
```

---

### 🔮 Cluster Visualization

#### Integration with mob.server
Visual cluster topology and monitoring.

**Features Needed:**
- Cluster topology graph (D3.js)
- Node health dashboard (memory, reductions, message queue)
- Process distribution visualization
- LiveView message flow diagram
- Real-time metrics with WebSocket updates

---

## Development Workflow Example

Here's how the tools work together in a typical development session:

```bash
# 1. Check environment
mix mob.doctor

# 2. List available devices
mix mob.devices

# 3. Connect to cluster
mix mob.connect

# 4. Monitor logs in real-time (new)
mix mob.logs --follow --level info

# 5. Take a screenshot (new)
mix mob.screen --capture debug_state.png

# 6. Start live preview (new)
mix mob.screen --preview --port 5050

# 7. Trace function calls (new)
mix mob.trace --modules MyApp,MyAppWeb

# 8. Make changes and auto-deploy
mix mob.watch

# 9. Run benchmarks (proposed)
mix mob.bench --compare node1,node2

# 10. Debug specific process (proposed)
mix mob.debug --inspect MyApp.Worker
```

---

## Implementation Priority

### High Priority (Implement Next)
1. ✅ **LogCollector** - Done
2. ✅ **ScreenCapture** - Done
3. ✅ **Tracing** - Done (basic)
4. 🔮 **Debugger** - Process inspection, state introspection
5. 🔮 **Benchmark** - Performance measurement

### Medium Priority
6. 🔮 **NetworkDiag** - Connectivity diagnostics
7. 🔮 **Cluster Visualization** - Web-based dashboard

### Nice to Have
8. 🔮 **Crash Dump Analysis** - Parse and analyze BEAM crash dumps from devices
9. 🔮 **A/B Testing Framework** - Run experiments across device clusters
10. 🔮 **Performance Profiling** - CPU profiling via `:eprof`/`fprof` on remote nodes

---

## Testing Strategy

Per `AGENTS.md`, TDD is the practice in mob_dev. Each new module should have:

1. **Unit tests** in `test/mob_dev/` (aim for 80%+ coverage)
2. **Public APIs** for testing (see AGENTS.md public seam rules)
   - Parsers: `parse_*/1` functions
   - Predicates: `available?/0`, `valid?/1` functions
3. **Integration tests** (tagged `@tag :integration`) for device-dependent features
4. **Mock devices** for testing without physical hardware (use `MobDev.Device` struct)

### Example Test Structure:
```
test/mob_dev/log_collector_test.exs
test/mob_dev/screen_capture_test.exs
test/mob_dev/tracing_test.exs
test/mix/tasks/mob.logs_test.exs
test/mix/tasks/mob.screen_test.exs
```

### Running Tests:
```bash
mix test                       # All tests
mix test --exclude integration # Skip device-dependent tests
mix test test/mob_dev/log_collector_test.exs  # Single file
```

---

## Dependencies & Assumptions

### Required Tools
- **Android**: `adb` (Android Debug Bridge) - part of Android SDK
- **iOS Simulator**: `xcrun simctl`, Xcode command line tools
- **iOS Physical**: `libimobiledevice` (for `idevicesyslog`, `idevicescreenshot`, etc.)
- **Erlang/Elixir**: `:rpc`, `:erlang.trace`, `:logger` modules

### Graceful Degradation
All tools should:
- Detect available tools and degrade gracefully (e.g., skip iOS features if Xcode not installed)
- Provide clear error messages when tools are missing
- Work with both physical devices and simulators/emulators
- Support both Android and iOS platforms
- Return `{:error, reason}` tuples instead of raising (unless it's a programming error)

---

## Contributing

When adding new tools:

1. Follow existing patterns in `lib/mob_dev/bench/` for reference
2. Use `MobDev.Utils.compile_regex/2` for regex (never `Regex.compile!` - see AGENTS.md)
3. Make functions public if they need testing (see AGENTS.md public seam rules)
4. Add comprehensive `@doc` and `@spec` annotations
5. Handle errors with `{:ok, result} | {:error, reason}` patterns
6. Update this document with new capabilities
7. Keep `AGENTS.md` up to date (same commit as the change)
8. Run pre-commit checklist: `mix test`, `mix format`, `mix credo --strict`

---

## References

- [AGENTS.md](../AGENTS.md) - Repository conventions and public seams
- [CLAUDE.md](CLAUDE.md) - Agent-specific workflow instructions
- [build_release.md](build_release.md) - OTP release build process
- [REFACTORING.md](REFACTORING.md) - Codebase refactoring history
- [plan.md](plan.md) - Roadmap and feature planning
