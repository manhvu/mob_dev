# dala_dev

Development tooling for [Dala](https://hexdocs.pm/dala) — the BEAM-on-device mobile framework for Elixir.

[![Hex.pm](https://img.shields.io/hexpm/v/dala_dev.svg)](https://hex.pm/packages/dala_dev)

Original repo [mob_dev](https://github.com/GenericJam/mob_dev) — now part of the [Dala](https://github.com/manhvu/dala) ecosystem.

**Dual licensed under:**
- **MIT License** (for original Mob project portions) - see [LICENSE](LICENSE)
- **Apache License 2.0** (for new contributions) - see [LICENSE-APACHE](LICENSE-APACHE)

## Project Structure:

```
dala_dev/
├── lib/
│   ├── mob_dev/                # Core modules (DalaDev.* namespace)
│   │   ├── discovery/          # Device discovery modules
│   │   │   ├── android.ex      # Android device discovery via adb
│   │   │   └── ios.ex          # iOS simulator/device discovery via xcrun simctl
│   │   ├── bench/              # Battery benchmarking modules
│   │   │   ├── probe.ex        # Multi-source state probing (battery, app state)
│   │   │   ├── logger.ex       # CSV logging for benchmark runs
│   │   │   ├── summary.ex      # Post-run analysis and statistics
│   │   │   ├── preflight.ex    # Pre-run checklist (device ready, app installed)
│   │   │   ├── reconnector.ex  # Auto-reconnect logic for flapping connections
│   │   │   └── device_observer.ex  # Device event subscription (app state changes)
│   │   ├── server/             # Phoenix dev dashboard
│   │   │   ├── endpoint.ex     # Phoenix endpoint
│   │   │   ├── router.ex       # Route definitions
│   │   │   ├── device_poller.ex # Periodic device discovery
│   │   │   ├── watch_worker.ex  # File watch and auto-push
│   │   │   └── ...             # Log streaming, buffering, filtering
│   │   ├── deployer.ex         # Main deployment logic (BEAM + native apps)
│   │   ├── hot_push.ex         # Hot-push changed modules via RPC (no restart)
│   │   ├── connector.ex        # Discovery → tunnel → restart → connect orchestration
│   │   ├── tunnel.ex           # Port tunneling (adb forward/reverse, iproxy)
│   │   ├── native_build.ex     # APK/.app bundle building and signing
│   │   ├── otp_downloader.ex    # Pre-built OTP runtime downloads and caching
│   │   ├── device.ex           # Unified device struct with common interface
│   │   ├── config.ex           # Configuration handling (dala.exs)
│   │   ├── utils.ex            # Centralized utility functions (regex, ADB helpers)
│   │   ├── paths.ex            # Path resolution for OTP runtimes, SDKs, build artifacts
│   │   ├── error.ex            # Standardized error handling and formatting
│   │   ├── crash_dump.ex       # Crash dump parsing and HTML reports
│   │   ├── emulators.ex        # Emulator lifecycle management
│   │   ├── profiling.ex        # Profiling and flame graph generation
│   │   ├── tracing.ex          # Distributed tracing infrastructure
│   │   ├── observer.ex         # Remote node observation (web-based :observer)
│   │   ├── debugger.ex         # Interactive remote debugging
│   │   ├── log_collector.ex    # Log collection and streaming
│   │   ├── screen_capture.ex   # Screenshot and video capture
│   │   ├── network.ex          # Network diagnostics
│   │   ├── benchmark.ex        # Performance benchmarking
│   │   ├── release.ex          # Release build utilities
│   │   ├── icon_generator.ex   # Icon generation for Android/iOS
│   │   ├── enable.ex           # Feature enablement
│   │   ├── qr.ex               # QR code generation
│   │   └── ...
│   └── mix/tasks/              # Mix task implementations (mix dala.*)
│       ├── dala.deploy.ex      # Deploy builds to devices
│       ├── dala.push.ex        # Hot-push changed modules (no restart)
│       ├── dala.connect.ex     # Connect to running device nodes
│       ├── dala.devices.ex     # List connected devices
│       ├── dala.server.ex      # Dev dashboard server (Phoenix)
│       ├── dala.web.ex         # Comprehensive web UI
│       ├── dala.release.ex     # Build signed iOS .ipa
│       ├── dala.release.android.ex # Build signed Android .aab
│       ├── dala.publish.ex     # Upload .ipa to TestFlight
│       ├── dala.publish.android.ex # Upload .aab to Google Play
│       ├── dala.install.ex     # First-run setup
│       ├── dala.enable.ex      # Enable optional features
│       ├── dala.doctor.ex      # Diagnose setup issues
│       ├── dala.provision.ex   # iOS provisioning
│       ├── dala.routes.ex      # Navigation validation
│       ├── dala.debug.ex       # Interactive debugging
│       ├── dala.observer.ex    # Web-based Observer
│       ├── dala.logs.ex        # Log collection
│       ├── dala.trace.ex       # Distributed tracing
│       ├── dala.bench.ex       # Performance benchmarks
│       ├── dala.screen.ex      # Screenshots and video
│       ├── dala.emulators.ex   # Emulator management
│       ├── dala.cache.ex       # Cache management
│       ├── dala.icon.ex        # Icon generation
│       ├── dala.gen.live_screen.ex # LiveView+Screen generation
│       ├── dala.watch.ex       # Watch-mode development
│       ├── dala.watch_stop.ex  # Stop watch session
│       ├── dala.battery_bench_android.ex # Android battery bench
│       ├── dala.battery_bench_ios.ex     # iOS battery bench
│       └── ...
├── test/                       # Test files (mirrors lib/ structure)
│   ├── dala_dev/               # Unit tests for lib/dala_dev/*
│   └── mix/tasks/             # Tests for Mix tasks
├── scripts/
│   └── release/                # OTP cross-compilation scripts
│       ├── xcompile_android.sh         # Android arm64/arm32 cross-compile
│       ├── xcompile_ios_device.sh      # iOS device (arm64) cross-compile
│       ├── xcompile_ios_sim.sh         # iOS simulator (x86_64/arm64) cross-compile
│       └── patches/            # OTP patches for iOS device compatibility
│           ├── forker_start    # Skip forker_start (fork issues on iOS)
│           └── epmd_no_daemon  # EPMD NO_DAEMON guard (prevents daemonization)
├── priv/
│   └── templates/              # EEx templates for project generation (mix dala.new)
└── guides/                     # Additional documentation
    └── ...
```

For more details on the codebase architecture and development practices, see [AGENTS.md](AGENTS.md).

## Command Reference

For a complete guide to all `mix dala.*` commands with detailed explanations of how they work, see:
- **[Dala Commands Guide](guides/dala_commands.md)** — Complete reference with usage, options, and internals

### Quick Command Overview

| Command | Description |
|---------|-------------|
| `mix dala.devices` | List connected Android and iOS devices |
| `mix dala.connect` | Connect IEx to running device nodes |
| `mix dala.deploy` | Build and deploy to connected devices |
| `mix dala.push` | Hot-push changed modules (no restart) |
| `mix dala.server` | Start dev dashboard (localhost:4040) |
| `mix dala.web` | Start comprehensive web UI |
| `mix dala.emulators` | Manage Android emulators and iOS simulators |
| `mix dala.doctor` | Diagnose setup and configuration issues |
| `mix dala.provision` | iOS provisioning profile management |
| `mix dala.release` | Build signed iOS .ipa for distribution |
| `mix dala.release.android` | Build signed Android .aab for distribution |
| `mix dala.publish` | Upload .ipa to App Store Connect / TestFlight |
| `mix dala.publish.android` | Upload .aab to Google Play Console |
| `mix dala.install` | First-run setup: download OTP, generate icons |
| `mix dala.enable` | Enable optional Dala features |
| `mix dala.icon` | Regenerate app icons from source image |
| `mix dala.cache` | Show or clear machine-wide caches |
| `mix dala.routes` | Validate navigation destinations |
| `mix dala.screen` | Capture screenshots, record video |
| `mix dala.debug` | Interactive debugging for dala nodes |
| `mix dala.observer` | Web-based Observer for remote nodes |
| `mix dala.logs` | Collect and stream logs from devices |
| `mix dala.trace` | Distributed tracing for dala clusters |
| `mix dala.bench` | Run performance benchmarks |
| `mix dala.gen.live_screen` | Generate a LiveView + Dala.Screen pair |
| `mix dala.watch` | Auto-deploy on file changes |
| `mix dala.watch_stop` | Stop a running watch session |
| `mix dala.battery_bench_android` | Android battery benchmarking |
| `mix dala.battery_bench_ios` | iOS battery benchmarking |

See the [full guide](guides/dala_commands.md) for detailed usage, options, and "under the hood" explanations.

## Architecture Overview

dala_dev follows a modular architecture with clear separation of concerns:

### Discovery Layer (`DalaDev.Discovery.*`)
Discovers connected devices using platform-specific tools:
- **Android**: Uses `adb devices -l` to list connected Android devices and emulators
- **iOS**: Uses `xcrun simctl list -j` for simulators and `devicectl` for physical devices
- **Output**: Returns normalized `DalaDev.Device` structs with platform, ID, status, and metadata

### Tunnel Layer (`DalaDev.Tunnel`)
Establishes network tunnels for Erlang distribution between dev machine and devices:
- **Android**: Uses `adb forward` and `adb reverse` to tunnel EPMD and distribution ports
- **iOS**: Uses `iproxy` (from libimobiledevice) to forward ports to the device
- **Purpose**: Enables `Node.connect/1` and RPC calls to device nodes

### Deployment Layer (`DalaDev.Deployer`, `DalaDev.HotPush`)
Handles both full deployment and hot-pushing:
- **Full deployment** (`DalaDev.Deployer`): Builds native app → installs → pushes BEAM files → restarts
- **Hot-push** (`DalaDev.HotPush`): Pushes only changed BEAM files via RPC → no restart needed
- **Fallback**: If dist isn't reachable, falls back to `adb push` + app restart

### Build Layer (`DalaDev.NativeBuild`)
Compiles native Android/iOS apps and manages OTP runtimes:
- **Native builds**: Compiles APK (Android) or .app (iOS) using platform tools
- **OTP downloads**: Downloads pre-built OTP tarballs via `DalaDev.OtpDownloader`
- **Cross-compilation**: Scripts in `scripts/release/` for building OTP from source

### Dashboard Layer (`DalaDev.Server`)
Provides web-based development dashboard with live feedback:
- **Phoenix server**: Runs at `localhost:4040` with real-time updates
- **Device cards**: Live status, deploy buttons, log streaming
- **Watch mode**: Auto-push changed BEAMs on file save
- **PubSub**: Uses Phoenix PubSub for live updates via WebSocket

## Installation

### Documentation

- **[Architecture Guide](guides/architecture.md)** — Complete technical reference for dala_dev architecture
- **[Dala Commands Guide](guides/dala_commands.md)** — Complete reference for all `mix dala.*` commands
- **[AGENTS.md](AGENTS.md)** — Developer guide for contributing to dala_dev
- **[build_release.md](build_release.md)** — Release build walkthrough
- **[publishing_to_testflight.md](guides/publishing_to_testflight.md)** — iOS TestFlight publishing

### Prerequisites

Before installing dala_dev, ensure you have:

**For Android development**:
- Android SDK installed with `adb` in PATH
- At least one Android emulator or connected device
- Android API level 26+ (Android 8.0+)

**For iOS development**:
- macOS with Xcode 15+ installed
- `xcrun` command-line tools available
- For physical devices: `brew install libimobiledevice` for device management
- iOS 14+ for physical devices, iOS 15+ for simulators

**For all platforms**:
- Elixir 1.18+ and Erlang/OTP 26+
- Node.js (optional, for MCP tools)

### Adding to Your Project

Add to your project's `mix.exs` (dev only):

```elixir
  def deps do
    [
      {:dala_dev, "~> 0.2", only: :dev}
    ]
  end
```

Then run:

```bash
mix deps.get
mix dala.install   # First-run setup: download OTP runtime, generate icons, write dala.exs
```

The `mix dala.install` command will:
1. Download pre-built OTP runtime for your target platforms
2. Generate app icons for Android and iOS
3. Create `dala.exs` configuration file in your project root

## Navigation validation (`mix dala.routes`)

Validates all `push_screen`, `reset_to`, and `pop_to` destinations across `lib/**/*.ex` via AST analysis. Module destinations are verified with `Code.ensure_loaded/1`.

```bash
mix dala.routes           # print warnings
mix dala.routes --strict  # exit non-zero (for CI)
```
| Task | Description | Example Usage |
|------|-------------|---------------|
| `mix dala.new APP_NAME` | Generate a new Dala project (see `dala_new` archive) | `mix dala.new MyApp` |
| `mix dala.install` | First-run setup: download OTP runtime, generate icons, write `dala.exs` | `mix dala.install` |
| `mix dala.deploy` | Compile and push BEAMs to all connected devices | `mix dala.deploy` |
| `mix dala.deploy --native` | Also build and install the native APK/iOS app | `mix dala.deploy --native --ios` |
| `mix dala.connect` | Tunnel + restart + open IEx connected to device nodes | `mix dala.connect` |
| `mix dala.connect --name my_node` | Connect with a named node (for multiple sessions) | `mix dala.connect --name dev@127.0.0.1` |
| `mix dala.watch` | Auto-push BEAMs on file save | `mix dala.watch` |
| `mix dala.watch_stop` | Stop a running `mix dala.watch` | `mix dala.watch_stop` |
| `mix dala.devices` | List connected devices and their status | `mix dala.devices` |
| `mix dala.push` | Hot-push only changed modules (no restart) | `mix dala.push --all` |
| `mix dala.server` | Start the dev dashboard at `localhost:4040` | `mix dala.server` |
| `mix dala.icon` | Regenerate app icons from a source image | `mix dala.icon --source assets/logo.png` |
| `mix dala.routes` | Validate navigation destinations across the codebase | `mix dala.routes --strict` |
| `mix dala.battery_bench_android` | Measure BEAM idle power draw on an Android device | `mix dala.battery_bench_android --duration 1800` |
| `mix dala.battery_bench_ios` | Measure BEAM idle power draw on a physical iOS device | `mix dala.battery_bench_ios --wifi-ip 10.0.0.120` |
| `mix dala.provision` | Handle iOS provisioning profiles and certificates | `mix dala.provision` |
| `mix dala.doctor` | Diagnose common setup and configuration issues | `mix dala.doctor` |
| `mix dala.emulators` | Manage and launch emulators/simulators | `mix dala.emulators` |

For detailed help on any task, run `mix help dala.<task>`.

## Dev dashboard (`mix dala.server`)

`mix dala.server` starts a local Phoenix server (default port 4040) with:

- **Device cards** — live status for connected Android emulators and iOS simulators, with Deploy and Update buttons per device
- **Device log panel** — streaming logcat / iOS simulator console with text filter
- **Elixir log panel** — Elixir `Logger` output forwarded from the running BEAM, with text filter
- **Watch mode toggle** — auto-push changed BEAMs on file save without running a separate terminal
- **QR code** — LAN URL for opening the dashboard on a physical device

Run with IEx for an interactive terminal alongside the dashboard:

```bash
iex -S mix dala.server
```

### Watch mode

Click **Watch** in the dashboard header or control it programmatically:

```elixir
DalaDev.Server.WatchWorker.start_watching()
DalaDev.Server.WatchWorker.stop_watching()
DalaDev.Server.WatchWorker.status()
#=> %{active: true, nodes: [:"my_app_ios@127.0.0.1"], last_push: ~U[...]}
```

Watch events broadcast on `"watch"` PubSub topic:

```elixir
{:watch_status, :watching | :idle}
{:watch_push,   %{pushed: [...], failed: [...], nodes: [...], files: [...]}}
```

## Hot-push transport (`mix dala.deploy`)

When Erlang distribution is reachable, `mix dala.deploy` hot-pushes changed BEAMs in-place via RPC — no `adb push`, no app restart. The running modules are replaced exactly like `nl/1` in IEx.

```
Pushing 14 BEAM file(s) to 2 device(s)...
  Pixel_7_API_34  →  pushing... ✓ (dist, no restart)
  iPhone 15 Pro   →  pushing... ✓ (dist, no restart)
```

If dist is not reachable (first deploy, app not running), it falls back to `adb push` + restart. Mixed deploys work — one device can hot-push while another restarts.

**Requirements:** The app must call `Dala.Connectivity.Dist.ensure_started/1` at startup, and the cookie must match the one in `dala.exs` (default `:dala_secret`).

## Navigation validation (`mix dala.routes`)

Validates all `push_screen`, `reset_to`, and `pop_to` destinations across `lib/**/*.ex` via AST analysis. Module destinations are verified with `Code.ensure_loaded/1`.

```bash
mix dala.routes           # print warnings
mix dala.routes --strict  # exit non-zero (for CI)
```

```
✓ 12 navigation reference(s) valid (2 dynamic/named skipped)

# On failure:
✗ 1 unresolvable navigation destination(s):
  lib/my_app/home_screen.ex:42  push_screen(socket, MyApp.SettingsScren)
    Module MyApp.SettingsScren could not be loaded.
```

Dynamic destinations (`push_screen(socket, var)`) and registered name atoms (`:main`) are skipped with a note.

## Battery benchmarks

Measure BEAM idle power draw with specific tuning flags. Both tasks share the same presets and flag interface.

### Android (`mix dala.battery_bench_android`)

Deploys an APK and measures drain via the hardware charge counter (`dumpsys
battery`). Reports mAh every 10 seconds. Uses the same probe / observer /
CSV-log / preflight infrastructure as the iOS bench.

**WiFi ADB required** — a USB cable charges the device and skews measurements.

```bash
# One-time WiFi ADB setup (while plugged in):
adb -s SERIAL tcpip 5555
adb connect PHONE_IP:5555
# then unplug
```

#### Two-step workflow (recommended)

Same pattern as iOS — push BEAM flags via `mix dala.deploy`, then bench
with `--no-build`. Saves the Gradle rebuild (~30+ seconds) when only
changing flags.

```bash
mix dala.deploy --beam-flags "" --android                # tuned (Nerves)
mix dala.deploy --beam-flags "-S 4:4 -A 8" --android     # untuned variant

mix dala.battery_bench_android --no-build --device 192.168.1.42:5555
```

The bench will:
- Run preflight checks (adb device, app installed, BEAM reachable, RPC
  responsive, NIF version, keep-alive NIF)
- Subscribe to `Dala.Device` events on the running app for ground-truth
  screen/app-state tracking
- Write a per-tick CSV log to `_build/bench/run_android_<ts>.csv`
- Auto-reconnect with backoff if the dist connection flaps
- Print a probe-based summary at the end with success rate, reconnect
  count, time-by-state, screen-on/off durations, and **taint warnings**

#### Single-step Gradle path

Still supported when you want a clean rebuild:

```bash
mix dala.battery_bench_android                              # default: Nerves-tuned BEAM, 30 min
mix dala.battery_bench_android --no-beam                    # baseline: no BEAM at all
mix dala.battery_bench_android --preset untuned             # raw BEAM, no tuning
mix dala.battery_bench_android --flags "-sbwt none -S 1:1"
mix dala.battery_bench_android --duration 3600 --device 192.168.1.42:5555
mix dala.battery_bench_android --no-build                   # re-run without rebuilding
```

#### Recovering from bad flags

`mix dala.deploy --beam-flags "..."` saves to `dala.exs` so the flags persist
across runs. If a flag combination crashes the BEAM, every subsequent
deploy re-applies them. Push an empty string to clear:

```bash
mix dala.deploy --beam-flags "" --android
```

### iOS (`mix dala.battery_bench_ios`)

Deploys to a physical iPhone/iPad and reads battery via `ideviceinfo` (USB)
or via Erlang RPC over WiFi. Reports mAh (if `BatteryMaxCapacity` is
available) or percentage points.

**Prerequisites:** `brew install libimobiledevice`, Xcode 15+, device
trusted on this Mac, phone on the same WiFi as the Mac.

#### Two-step workflow (recommended)

For Dala projects (which use `ios/build_device.sh` rather than a full Xcode
project), you can't rebuild + bench in one command — the bench task's
built-in `xcodebuild` path doesn't support the Dala build system. Instead,
do the two steps separately:

```bash
# Step 1 — deploy with whatever BEAM flags you want.
# This pushes the .beam files PLUS a runtime dala_beam_flags file that
# the launcher reads at startup. No native rebuild required (~5 seconds).
mix dala.deploy --beam-flags "" --ios                       # tuned (Nerves defaults)
mix dala.deploy --beam-flags "-S 6:6 -A 16" --ios           # untuned variant
mix dala.deploy --ios                                       # uses flags saved in dala.exs

# Step 2 — run the bench with --no-build, since we already deployed.
mix dala.battery_bench_ios --no-build --wifi-ip 10.0.0.120
mix dala.battery_bench_ios --no-build --wifi-ip 10.0.0.120 --duration 600
mix dala.battery_bench_ios --no-build --wifi-ip 10.0.0.120 --skip-preflight
```

Find your phone's WiFi IP in **Settings → Wi-Fi → (i) → IP Address**.

`--wifi-ip` is strongly recommended — without it the bench tries to
auto-discover the device, which is flaky for WiFi-only setups (we've seen
it pick up the Mac's own EPMD or simulator nodes).

#### What the bench shows you

A live trace per 10-second poll, with state per tick:

```
[02:33:00] 0.5/30 min — screen:off app:running rpc:ok battery:100% (−0.0 %)
```

A CSV log in `_build/bench/run_<ts>.csv` (every sample, every state).

A probe-based summary at the end with success rate, reconnect count,
longest gap, time-by-state, screen-on/off durations, and **taint warnings**
that catch invalid runs (screen turned on, app died, majority unreachable,
flapping connection).

#### Recovering from bad flags

`mix dala.deploy --beam-flags "..."` saves the flags to `dala.exs` so they
persist across runs. If a flag combination crashes the BEAM (e.g.
requesting more threads than iOS allows per process), every subsequent
`mix dala.deploy` re-applies the same bad flags and the app keeps crashing.

To recover, push an empty flags string — clears `dala.exs` *and* the
runtime override file on every device:

```bash
mix dala.deploy --beam-flags "" --ios
```

#### Flag prefix convention (iOS)

The Dala iOS BEAM build is conservative about flag syntax. Match the
compile-time defaults' format — `-` prefix, space-separated values:

```
-S 1:1 -SDcpu 1:1 -SDio 1 -A 1 -sbwt none      ← compile-time defaults (Nerves)
```

When in doubt, copy that pattern. We've observed `+S 6:6 +A 64 +SDio 8`
crashing the BEAM at startup with no useful log line — likely because the
combined thread count exceeds iOS's per-process limit. Build untuned
configs incrementally:

```bash
# Smallest delta from defaults — multi-scheduler but everything else minimal:
mix dala.deploy --beam-flags "-S 2:2 -SDcpu 2:2 -SDio 2 -A 2" --ios
# Bench. If the app launches and runs, ramp up:
mix dala.deploy --beam-flags "-S 6:6 -SDcpu 6:6 -SDio 6 -A 8" --ios
```

#### Other options

```bash
mix dala.battery_bench_ios --no-build --wifi-ip 10.0.0.120 --no-keep-alive
# Skips the silent-audio keep-alive call. Use when the keep-alive NIF is
# misbehaving or you want to verify how much drain comes from background
# audio session vs the BEAM itself.

mix dala.battery_bench_ios --no-build --wifi-ip 10.0.0.120 --skip-preflight
# Bypass the pre-flight checks (useful when the checks are spuriously
# failing on devicectl noise or similar).

mix dala.battery_bench_ios --no-build --wifi-ip 10.0.0.120 --no-csv
# Don't write the CSV log (run is purely live-trace + final summary).

mix dala.battery_bench_ios --no-build --wifi-ip 10.0.0.120 --log-path /tmp/run.csv
```

### Presets and results

| Preset | Flags | mAh/hr (Moto G, screen on, low brightness) |
|--------|-------|----------------|
| No BEAM | — | ~200 |
| Nerves (default) | `-S 1:1 -SDcpu 1:1 -SDio 1 -A 1 -sbwt none` | ~202 |
| Untuned | *(none)* | ~250 |

The Nerves-tuned BEAM is essentially indistinguishable from a stock Android app at idle. The untuned BEAM costs ~25% more because schedulers spin-wait instead of sleeping.

**iOS results** are tracked separately in `dala/guides/why_beam.md` (different
device, different methodology — physical iPhone with screen on/off
distinction). The `--preset` shortcuts (`untuned`/`sbwt`/`nerves`) aren't
useful on iOS because they require a full Xcode rebuild (which Dala projects
don't have), so on iOS you set flags via `mix dala.deploy --beam-flags ...`
and bench with `--no-build`.

### Battery-read precision (iOS)

iOS clamps `UIDevice.batteryLevel` to **5% increments** as a privacy
measure. So a 1% drain over 30 minutes shows as `100% → 100%` in the
bench's RPC reads. To get a precise final number:

1. After the bench finishes (and prints both summaries), the iOS bench now
   prompts you to plug in USB and press Enter. This calls `ideviceinfo`'s
   battery domain which returns 1% precision over USB.
2. You'll see fields like:

   ```
   === Precise battery (via ideviceinfo) ===
     BatteryCurrentCapacity: 99
     BatteryIsCharging: true
     ExternalConnected: true
     FullyCharged: false
   ```

3. Compare to the start-of-run reading the bench printed at the top.

You can also read precise battery any time by hand:

```bash
ideviceinfo -u <UDID> -q com.apple.mobile.battery
```

This caveat doesn't apply to Android — `dumpsys battery` returns 1%
precision natively.

### Duration unit

`--duration N` is in **seconds** on both bench tasks. Default 1800 = 30
minutes. The bench's live trace and summaries always show
`elapsed_min / total_min` for readability, but the CLI flag is seconds.

## Working with an agent (Claude Code / LLM)

Because OTP runs on the device, an agent can connect directly to the running app via Erlang distribution and inspect or drive it programmatically — no screenshots required.

### How it works

```
Agent (Claude Code)
    │
    ├── mix dala.connect      → tunnels EPMD, connects IEx to device node
    │
    ├── Dala.Test.*           → inspect screen state, trigger taps via RPC
    │   (exact state: module, assigns, render tree)
    │
    └── MCP tools            → native UI when needed
        ├── adb-mcp          → Android: screenshot, shell, UI inspect
        └── ios-simulator-mcp → iOS: screenshot, tap, describe UI
```

### Dala.Test — preferred for agents

`Dala.Test` gives exact app state via Erlang distribution. Prefer it over screenshots whenever possible — it doesn't depend on rendering, is instantaneous, and works offline.

```elixir
node = :"my_app_ios@127.0.0.1"

# Inspection
Dala.Test.screen(node)               #=> MyApp.HomeScreen
Dala.Test.assigns(node)              #=> %{count: 3, user: %{name: "Alice"}, ...}
Dala.Test.find(node, "Save")         #=> [{[0, 2], %{"type" => "button", ...}}]
Dala.Test.inspect(node)              # full snapshot: screen + assigns + nav history + tree

# Tap a button by tag atom (from on_tap: {self(), :save} in render/1)
Dala.Test.tap(node, :save)

# Navigation — synchronous, safe to read state immediately after
Dala.Test.back(node)                 # system back gesture (fire-and-forget)
Dala.Test.pop(node)                  # pop to previous screen (synchronous)
Dala.Test.navigate(node, MyApp.DetailScreen, %{id: 42})
Dala.Test.pop_to(node, MyApp.HomeScreen)
Dala.Test.pop_to_root(node)
Dala.Test.reset_to(node, MyApp.HomeScreen)

# List interaction
Dala.Test.select(node, :my_list, 0)  # select first row
```

# Simulate device API results (permission dialogs, camera, location, etc.)
Dala.Test.send_message(node, {:permission, :camera, :granted})
Dala.Test.send_message(node, {:camera, :photo, %{path: "/tmp/p.jpg", width: 1920, height: 1080}})
Dala.Test.send_message(node, {:location, %{lat: 43.65, lon: -79.38, accuracy: 10.0, altitude: 80.0}})
Dala.Test.send_message(node, {:notification, %{id: "n1", title: "Hi", body: "Hey", data: %{}, source: :push}})
Dala.Test.send_message(node, {:biometric, :success})
```

### Accessing IEx alongside an agent

**Option 1 — shared session (`iex -S mix dala.server`):**

```bash
iex -S mix dala.server
```

Starts the dev dashboard and gives you an IEx prompt in the same process. The agent uses Tidewave to execute `Dala.Test.*` calls in this session; you type directly in the same IEx prompt. Both share the same connected node and see the same live state. This is the recommended setup for working alongside an agent.

**Option 2 — separate sessions (`--name`):**

Because Erlang distribution allows multiple nodes to connect to the same device, you can run independent sessions simultaneously:

```bash
# Your terminal
mix dala.connect --name dala_dev_1@127.0.0.1

# Agent's terminal (or a second developer)
mix dala.connect --name dala_dev_2@127.0.0.1
```

Both connect to the same device nodes, can call `Dala.Test.*` and `nl/1`, and don't interfere with each other.

### MCP tool setup

For native UI interaction (screenshots, native gestures, accessibility inspection), install MCP servers for Claude Code:

**Android — `adb-mcp`:**

```bash
npm install -g adb-mcp
```

Add to `~/.claude.json`:

```json
{
  "mcpServers": {
    "adb": {
      "command": "npx",
      "args": ["adb-mcp"]
    }
  }
}
```

**iOS simulator — `ios-simulator-mcp`:**

```bash
npm install -g ios-simulator-mcp
```

Add to `~/.claude.json`:

```json
{
  "mcpServers": {
    "ios-simulator": {
      "command": "ios-simulator-mcp"
    }
  }
}
```

With these installed, Claude Code can take screenshots, inspect the accessibility tree, and simulate gestures on the native device — useful when you need to verify layout or test native gesture paths.

### Recommended CLAUDE.md for Dala projects

Add a `CLAUDE.md` to your Dala project root to give an agent the context it needs:

````markdown
# MyApp — Agent Instructions

## Connecting to a running device

```bash
mix dala.connect          # discover, tunnel, connect IEx
mix dala.connect --no-iex # print node names without IEx
mix dala.devices          # list connected devices
```

Node names:
- iOS simulator:    `my_app_ios@127.0.0.1`
- Android emulator: `my_app_android_<serial-suffix>@127.0.0.1`

## Inspecting and driving the running app

Prefer `Dala.Test` over screenshots — it gives exact state, not a visual approximation.

```elixir
node = :"my_app_ios@127.0.0.1"

# Inspection
Dala.Test.screen(node)       # current screen module
Dala.Test.assigns(node)      # current assigns map
Dala.Test.find(node, "text") # find UI nodes by visible text
Dala.Test.inspect(node)      # full snapshot: screen + assigns + nav history + tree

# Interaction
Dala.Test.tap(node, :tag)              # tap by tag atom (from on_tap: {self(), :tag} in render/1)
Dala.Test.back(node)                   # system back gesture
Dala.Test.pop(node)                    # pop to previous screen (synchronous)
Dala.Test.navigate(node, Screen, %{})  # push a screen (synchronous)
Dala.Test.select(node, :list_id, 0)    # select a list row

# Simulate device API results
Dala.Test.send_message(node, {:permission, :camera, :granted})
Dala.Test.send_message(node, {:camera, :photo, %{path: "/tmp/p.jpg", width: 1920, height: 1080}})
Dala.Test.send_message(node, {:biometric, :success})
```

Navigation functions (`pop`, `navigate`, `pop_to`, `pop_to_root`, `reset_to`) are
synchronous — safe to read state immediately after.

`back/1` and `send_message/2` are fire-and-forget. If you need to wait:

```elixir
Dala.Test.back(node)
:rpc.call(node, :sys, :get_state, [:dala_screen])  # flush
Dala.Test.screen(node)
```

## Hot-pushing code changes

```bash
mix dala.push          # compile + push all changed modules to all connected devices
mix dala.push --all    # force-push every module
```

## Deploying

```bash
mix dala.deploy          # push changed BEAMs, restart
mix dala.deploy --native # full native rebuild + install
```
````

### Agent workflow example

A typical agent session for debugging or feature work:

```
1. mix dala.connect                        — connect to the running device node
2. Dala.Test.screen(node)                  — confirm which screen is showing
3. Dala.Test.assigns(node)                 — inspect current state
4. Dala.Test.tap(node, :some_button)       — interact with the UI
5. Dala.Test.screen(node)                  — confirm navigation happened
6. edit lib/my_app/screen.ex              — make a code change
7. mix dala.push                           — hot-push changed modules without restart
8. Dala.Test.assigns(node)                 — verify state updated as expected
```

For device API interactions, simulate the result rather than triggering real hardware:

```elixir
# Instead of actually opening the camera:
Dala.Test.tap(node, :take_photo)     # triggers handle_event → Dala.Camera.capture_photo
# Simulate the result:
Dala.Test.send_message(node, {:camera, :photo, %{path: "/tmp/test.jpg", width: 1920, height: 1080}})
Dala.Test.assigns(node)              # verify photo_path was stored
```

If you need to see the rendered UI, take a screenshot with the native MCP tool, then use `Dala.Test.find/2` to correlate what you see with the component tree.
