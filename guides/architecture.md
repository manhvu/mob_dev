# Dala Dev Architecture Guide

Complete technical reference for the dala_dev architecture, explaining how each layer works and interacts with other components.

## Table of Contents

- [Introduction](#introduction)
- [System Context](#system-context)
- [Core Architectural Layers](#core-architectural-layers)
  - [Discovery Layer](#discovery-layer)
  - [Tunnel Layer](#tunnel-layer)
  - [Deployment Layer](#deployment-layer)
  - [Build Layer](#build-layer)
  - [Dashboard Layer](#dashboard-layer)
  - [Other Key Modules](#other-key-modules)
- [Data Flow Examples](#data-flow-examples)
  - [mix dala.deploy Flow](#mix-daladeploy-flow)
  - [mix dala.connect Flow](#mix-dalaconnect-flow)
  - [mix dala.battery_bench_android Flow](#mix-dalabattery_bench_android-flow)
- [Key Design Decisions](#key-design-decisions)
  - [Test-Driven Development](#test-driven-development)
  - [Public API Seams](#public-api-seams)
  - [Error Handling](#error-handling)
  - [Configuration](#configuration)
- [Cross-Cutting Concerns](#cross-cutting-concerns)
  - [OTP Management](#otp-management)
  - [Device ID Resolution](#device-id-resolution)
  - [Platform-Specific Logic](#platform-specific-logic)
- [Gotchas and Operational Considerations](#gotchas-and-operational-considerations)
- [References](#references)

---

## Introduction

`dala_dev` is the build/deploy/devices toolkit for the [Dala](https://hexdocs.pm/dala) ecosystem — the BEAM-on-device mobile framework for Elixir.

### Three-Repo Topology

As described in the system-wide [AGENTS.md](../../dala/AGENTS.md), the dala ecosystem uses three repositories:

| Repository | Purpose |
|------------|---------|
| **dala** | Core framework: Elixir/OTP runtime for mobile, LiveView integration, NIF bridges |
| **dala_dev** | Development tooling: Mix tasks, device discovery, deployment, emulators, provisioning |
| **dala_deploy** | Production deployment: App store publishing, CI/CD pipelines, release management |

`dala_dev` sits between the core framework and production deployment, providing all the local development workflows.

---

## System Context

### Integration Points

```
┌─────────────────────────────────────────────────────────────┐
│                    Developer Machine                        │
│                                                             │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────┐  │
│  │  dala (app) │───▶│ dala_dev    │───▶│ dala_deploy │  │
│  │  Elixir src  │    │ (this repo) │    │ (prod)      │  │
│  └─────────────┘    └──────────────┘    └─────────────┘  │
│         │                   │                    │           │
│         ▼                   ▼                    ▼           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              Platform Tools                         │  │
│  │  Android: adb, Gradle, Android SDK                │  │
│  │  iOS: xcrun, xcodebuild, libimobiledevice        │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │                   │
         ▼                   ▼
┌─────────────────┐  ┌─────────────────┐
│ Android Devices │  │ iOS Devices     │
│ (physical/emul) │  │ (physical/sim)  │
└─────────────────┘  └─────────────────┘
```

### Key Responsibilities

- **Device Discovery**: Find connected Android/iOS devices and emulators
- **Tunnel Management**: Enable Erlang distribution between dev machine and devices
- **Deployment**: Push BEAM files and native apps to devices
- **Build Support**: Manage native builds and OTP runtimes
- **Development Dashboard**: Web UI for device management and logs
- **Provisioning**: iOS certificate and profile management
- **Benchmarking**: Battery and performance testing utilities

---

## Core Architectural Layers

### Discovery Layer

**Modules**: `DalaDev.Discovery.Android`, `DalaDev.Discovery.IOS`, `DalaDev.Device`

#### Purpose

Discovers connected devices using platform-specific tools and returns normalized device structs.

#### Android Discovery (`DalaDev.Discovery.Android`)

Uses `adb devices -l` to list devices:

```bash
$ adb devices -l
List of devices attached
emulator-5554          device product:sdk_gphone64_x86_64 model:Android_SDK_built_for_x86_64 device:emulator64_x86_64
R3CR50LJN1W            device usb:1-2 product:SM-G998B model:SM-G998B device:SM-G998B
```

**Parsing**: `parse_devices_output/1` converts this to `DalaDev.Device` structs with fields:
- `platform: :android`
- `serial`: ADB serial (e.g., `emulator-5554`, `R3CR50LJN1W`)
- `type`: `:emulator` or `:physical`
- `name`: Device model (e.g., `Android_SDK_built_for_x86_64`)
- `status`: `:connected`, `:unauthorized`, `:discovered`

#### iOS Discovery (`DalaDev.Discovery.IOS`)

Uses multiple tools depending on device type:

**Simulators** (macOS only):
```bash
xcrun simctl list -j devices booted
```
Parsed by `parse_simctl_json/1` and `parse_simctl_text/1`.

**Physical Devices** (requires `libimobiledevice`):
```bash
ideviceinfo -k UniqueDeviceID
ideviceinfo -k DeviceName
```
Returns `DalaDev.Device` structs with:
- `platform: :ios`
- `serial`: UDID (e.g., `abc123def456...`)
- `type`: `:simulator` or `:physical`
- `host_ip`: Device IP address (if available)

#### Unified Device Struct

```elixir
%DalaDev.Device{
  platform: :android | :ios,
  type: :physical | :simulator | :emulator,
  serial: String.t(),
  name: String.t() | nil,
  version: String.t() | nil,
  status: :connected | :booted | :discovered | :unauthorized | :error,
  host_ip: String.t() | nil,
  node: atom() | nil,
  # ... other fields
}
```

#### Public API Seams (for testing)

- `DalaDev.Discovery.Android.parse_devices_output/1`
- `DalaDev.Discovery.IOS.parse_simctl_json/1`
- `DalaDev.Discovery.IOS.parse_simctl_text/1`
- `DalaDev.Discovery.IOS.parse_runtime_version/1`

---

### Tunnel Layer

**Module**: `DalaDev.Tunnel`

#### Purpose

Establishes network tunnels for Erlang distribution between the development machine and devices.

#### How Erlang Distribution Works

Erlang nodes communicate via TCP using:
- **EPMD** (Erlang Port Mapper Daemon): Maps node names to ports (default port 4369)
- **Distribution port**: Each node listens on a random port for inter-node communication

#### Android Tunneling

Uses `adb forward` and `adb reverse`:

```bash
# Device → Mac (EPMD)
adb reverse tcp:4369 tcp:4369

# Mac → Device (distribution port)
adb forward tcp:9100 tcp:9100
```

This allows:
- Device EPMD to register with the Mac's EPMD
- Mac to connect to device's distribution port

#### iOS Tunneling

**Simulators**: Share the Mac's network stack — no tunneling needed. The simulator uses the Mac's network interfaces directly.

**Physical Devices**:
1. **USB**: `iproxy` (from `libimobiledevice`) forwards ports:
   ```bash
   iproxy 4369 4369 &  # EPMD
   iproxy 9100 9100 &  # Distribution
   ```

2. **WiFi**: Device and Mac on same network — direct TCP connection using device IP

3. **Tailscale**: Mesh VPN — works over any network including cellular

#### Connection Priority (iOS Physical)

The BEAM on the device auto-detects the best connection at startup:

| Priority | Connection | When |
|----------|------------|------|
| 1 | WiFi / LAN | Same network as Mac |
| 1 | Tailscale | Any network (install Tailscale on both) |
| 2 | USB only | Cable plugged in, no WiFi |
| 3 | None | No network available |

---

### Deployment Layer

**Modules**: `DalaDev.Deployer`, `DalaDev.HotPush`, `DalaDev.Connector`

#### Two Deployment Modes

**1. Full Deploy** (`DalaDev.Deployer`)

Complete pipeline: native app build → install → push BEAMs → restart.

```elixir
DalaDev.Deployer.deploy_all(
  restart: true,
  platforms: [:android, :ios],
  device: "emulator-5554"
)
```

Steps:
1. Build native app (if `--native`):
   - Android: `./gradlew assembleDebug`
   - iOS: `xcodebuild -scheme ... build`
2. Install native app:
   - Android: `adb install -r app.apk`
   - iOS: `xcrun simctl install booted app.app`
3. Push BEAM files:
   - If distribution reachable: Hot-push via RPC
   - Else: File push (`adb push` / `simctl spawn cp`)
4. Restart app (unless `--no-restart`)

**2. Hot Push** (`DalaDev.HotPush`)

Push only changed BEAM files without restarting the app:

```elixir
# Equivalent to :rpc.call(node, :code, :load_binary, [Module, path, beam_binary])
DalaDev.HotPush.push_beams(node, changed_modules)
```

Uses Erlang's `:code.load_binary/3` to load BEAMs into the running VM.

#### Key Function: `narrow_platforms_for_device/2`

**Module**: `DalaDev.NativeBuild.narrow_platforms_for_device/2`

This is the **single source of truth** for:
- Determining which platforms to build for
- Validating deployment targets

```elixir
# Example: User passes --device emulator-5554
platforms = DalaDev.NativeBuild.narrow_platforms_for_device([:android, :ios], "emulator-5554")
# Returns [:android] — iOS is filtered out
```

**Why it matters**: Without this function, you'd get spurious "No device matched" warnings and might build for the wrong platform.

#### Fallback Logic

If Erlang distribution isn't reachable (app not running, network issue):
1. Try file push:
   - Android: `adb push beam_files /data/data/<pkg>/files/lib/`
   - iOS: `xcrun simctl spawn <udid> cp beam_files <app_bundle>/`
2. Restart app to load new BEAMs

---

### Build Layer

**Modules**: `DalaDev.NativeBuild`, `DalaDev.OtpDownloader`

#### Native Builds

**Android** (using Gradle):

```elixir
DalaDev.NativeBuild.build_android(platform: :android, device: nil)
# Runs: ./gradlew assembleDebug
# Output: android/app/build/outputs/apk/debug/app-debug.apk
```

**iOS** (using xcodebuild):

```elixir
DalaDev.NativeBuild.build_ios(platform: :ios, device: nil)
# Runs: xcodebuild -scheme <app> -destination 'platform=iOS Simulator,...' build
# Output: ios/build/Products/Debug-iphonesimulator/<app>.app
```

#### OTP Management (`DalaDev.OtpDownloader`)

Downloads and caches pre-built OTP tarballs for mobile platforms:

| Platform | ABI | Cache Location |
|----------|-----|----------------|
| Android | arm64 | `~/.dala/cache/otp_android_arm64.tar.gz` |
| Android | arm32 | `~/.dala/cache/otp_android_arm32.tar.gz` |
| iOS | simulator (x86_64) | `~/.dala/cache/otp_ios_sim_x86_64.tar.gz` |
| iOS | simulator (arm64) | `~/.dala/cache/otp_ios_sim_arm64.tar.gz` |
| iOS | device (arm64) | `~/.dala/cache/otp_ios_device_arm64.tar.gz` |

**Schema Versioning**: `valid_otp_dir?/2` checks the schema version (not OTP hash) to invalidate caches when tarball structure changes.

```elixir
# Bump schema version in valid_otp_dir?/2 to invalidate all caches
def valid_otp_dir?(dir, schema_version) do
  # schema_version is the knob for cache invalidation
end
```

#### Cross-Compilation Scripts (`scripts/release/`)

For building OTP from source:

- `xcompile_android.sh` — Android arm64/arm32 using NDK toolchain
- `xcompile_ios_sim.sh` — iOS simulator (x86_64/arm64)
- `xcompile_ios_device.sh` — iOS device (arm64)

**Patches** (`scripts/release/patches/`):
- `forker_start` — Skip forker_start (fork issues on iOS)
- `epmd_no_daemon` — EPMD NO_DAEMON guard (prevents daemonization)

---

### Dashboard Layer

**Modules**: `DalaDev.Server`, `DalaDev.Server.Endpoint`, `DalaDev.Server.DevicePoller`

#### Architecture

```
┌────────────────────────────────────────────────────────────┐
│              Dala Dev Server (localhost:4040)           │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐ │
│  │          Phoenix + Bandit (no Cowboy)              │ │
│  │  - Bandit.PhoenixAdapter                          │ │
│  │  - LiveView for real-time UI                      │ │
│  └─────────────────────────────────────────────────────┘ │
│                          │                               │
│  ┌───────────────────────┼───────────────────────────┐  │
│  │                       ▼                           │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │          Phoenix.PubSub                     │  │  │
│  │  │  (live updates via WebSocket)               │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                       │                           │  │
│  │  ┌────────────────────┼────────────────────┐    │  │
│  │  │                    ▼                    │    │  │
│  │  │  DevicePoller (polls adb/xcrun)        │    │  │
│  │  │  LogStreamerSupervisor (logcat/simctl) │    │  │
│  │  │  WatchWorker (file watcher)             │    │  │
│  │  └─────────────────────────────────────────┘    │  │
│  └───────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

#### Key Components

**`DalaDev.Server.Endpoint`**:
- Bandit HTTP server on port 4040 (configurable)
- Serves LiveView pages and static assets
- Uses `Bandit.PhoenixAdapter` instead of Cowboy

**`DalaDev.Server.DevicePoller`**:
- Periodically polls `adb devices -l` and `xcrun simctl list -j`
- Publishes device updates via Phoenix.PubSub

**`DalaDev.Server.LogStreamerSupervisor`**:
- Streams logs from devices:
  - Android: `adb logcat`
  - iOS: `xcrun simctl spawn <udid> log stream`
- Buffers logs in `DalaDev.Server.LogBuffer`

**`DalaDev.Server.WatchWorker`**:
- Watches Elixir source files for changes
- Auto-deploys changed BEAMs via `DalaDev.HotPush`

#### Watch Mode

When you run `mix dala.watch` or enable watch in the dashboard:
1. FileSystem (Elixir library) monitors `lib/` for changes
2. On change, recompiles the specific module
3. Pushes BEAM to all connected devices via hot-push
4. No app restart needed

---

### Other Key Modules

#### `DalaDev.Emulators`

Manages Android AVDs and iOS simulators:

```elixir
# List all
DalaDev.Emulators.list_android()  # Returns {:ok, [%Emulators{}]}
DalaDev.Emulators.list_ios()

# Start/stop
DalaDev.Emulators.start_android("Pixel_8_API_34")
DalaDev.Emulators.stop_ios("abc123...")
```

#### `DalaDev.Provision`

Handles iOS provisioning via `xcodebuild`:

```elixir
# Development profile
Mix.Tasks.Dala.Provision.run([])

# Distribution profile
Mix.Tasks.Dala.Provision.run(["--distribution"])
```

Uses `xcodebuild -allowProvisioningUpdates build` to:
1. Register bundle ID with Apple
2. Create provisioning profile
3. Download to `~/Library/Developer/Xcode/.../Provisioning Profiles/`

#### `DalaDev.CrashDump`

Parses Erlang crash dumps from devices:

```elixir
DalaDev.CrashDump.parse_file("erl_crash.dump")
# Returns structured data: %{header: ..., nodes: ..., ...}

DalaDev.CrashDump.html_report(crash_dump)
# Generates HTML report for debugging
```

#### `DalaDev.Bench.*`

Battery benchmarking modules:

- `DalaDev.Bench.Probe` — Multi-source state probing (battery, app state)
- `DalaDev.Bench.Logger` — CSV logging for benchmark runs
- `DalaDev.Bench.Summary` — Post-run analysis and statistics
- `DalaDev.Bench.Preflight` — Pre-run checklist (device ready, app installed)
- `DalaDev.Bench.Reconnector` — Auto-reconnect logic for flapping connections
- `DalaDev.Bench.DeviceObserver` — Device event subscription (app state changes)

---

## Data Flow Examples

### mix dala.deploy Flow

```
User runs: mix dala.deploy --native --device emulator-5554
          │
          ▼
┌─────────────────────────────┐
│ Parse args (OptionParser)   │
│ --native, --device, etc.    │
└─────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────┐
│ Resolve platforms:                          │
│ DalaDev.NativeBuild.narrow_platforms_for_device/2 │
│ Input: [:android, :ios], "emulator-5554"   │
│ Output: [:android] (iOS filtered out)       │
└─────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────┐
│ Mix.Task.run("compile")     │
│ Compile Elixir sources     │
└─────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────┐
│ If --native:                               │
│ DalaDev.NativeBuild.build_all/1             │
│   ├─ Android: ./gradlew assembleDebug      │
│   └─ iOS: xcodebuild ... build             │
└─────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────┐
│ DalaDev.Deployer.deploy_all/1               │
│   ├─ Discover devices (Discovery Layer)    │
│   ├─ Set up tunnels (Tunnel Layer)          │
│   ├─ Push BEAMs:                           │
│   │    ├─ If dist reachable: HotPush (RPC) │
│   │    └─ Else: File push (adb/simctl)     │
│   └─ Restart app (unless --no-restart)      │
└─────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────┐
│ Print results to user       │
│ (deployed, failed counts)  │
└─────────────────────────────┘
```

### mix dala.connect Flow

```
User runs: mix dala.connect
          │
          ▼
┌─────────────────────────────┐
│ Mix.Task.run("app.config")  │
│ Load project configuration  │
└─────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────┐
│ DalaDev.Connector.connect_all/1             │
│   ├─ Discover devices (Discovery Layer)    │
│   ├─ Set up tunnels (Tunnel Layer)          │
│   ├─ Restart apps on devices                │
│   └─ Wait for Erlang nodes to come online   │
└─────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────┐
│ Start IEx session:                         │
│   ├─ Node.start(:"dala_dev@127.0.0.1")    │
│   ├─ Node.set_cookie(:dala_secret)          │
│   └─ Node.connect(device_node) for each     │
└─────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────┐
│ User interacts with IEx:    │
│   ├─ Node.list()            │
│   ├─ nl(MyModule)           │
│   └─ Dala.Test.* calls      │
└─────────────────────────────┘
```

### mix dala.battery_bench_android Flow

```
User runs: mix dala.battery_bench_android --duration 3600 --device 192.168.1.42:5555
          │
          ▼
┌─────────────────────────────────────────────┐
│ Preflight checks (DalaDev.Bench.Preflight): │
│   ├─ adb connected?                        │
│   ├─ App installed?                        │
│   ├─ BEAM running?                         │
│   └─ RPC reachable?                        │
└─────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────┐
│ If --native or no APK:                     │
│   ├─ Build benchmark APK                   │
│   └─ Install via adb install               │
└─────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────┐
│ Start benchmark:                           │
│   ├─ DalaDev.Bench.Probe.start/1           │
│   │    └─ Poll battery stats every 10 sec  │
│   ├─ DalaDev.Bench.Logger.start/1           │
│   │    └─ Write CSV to _build/bench/       │
│   └─ DalaDev.Bench.DeviceObserver.start/1  │
│        └─ Monitor app state changes         │
└─────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────┐
│ Run for --duration seconds (3600 = 1 hour) │
│   └─ Every 10 sec: probe battery, log CSV  │
└─────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────┐
│ Post-run:                                  │
│   ├─ DalaDev.Bench.Summary.analyze/1       │
│   │    └─ Calculate mAh, averages, etc.    │
│   └─ Print summary to user                  │
└─────────────────────────────────────────────┘
```

---

## Key Design Decisions

### Test-Driven Development

As mandated in `AGENTS.md`:

- **Write tests first**: Before implementing a new function or fixing a bug
- **Every function needs tests**: Public API, parsing logic, platform-specific code
- **Keep the suite green**: All tests must pass before merging
- **Integration tests**: Tagged with `@tag :integration`, require devices, excluded by default

Example test for `DalaDev.Discovery.Android.parse_devices_output/1`:

```elixir
test "parses emulator device" do
  output = """
  List of devices attached
  emulator-5554          device product:sdk_gphone64_x86_64 model:Android_SDK_built_for_x86_64 device:emulator64_x86_64
  """

  devices = DalaDev.Discovery.Android.parse_devices_output(output)
  assert [%DalaDev.Device{serial: "emulator-5554", type: :emulator}] = devices
end
```

### Public API Seams

Intentional public functions for testing (DO NOT make private):

- Parsing functions (Android/iOS device discovery)
- `DalaDev.NativeBuild.narrow_platforms_for_device/2`
- `DalaDev.NativeBuild.ios_toolchain_available?/0`
- `DalaDev.OtpDownloader.valid_otp_dir?/2`

These allow testing parsing and logic in isolation without real devices.

### Error Handling

**Module**: `DalaDev.Error`

Standardized error formatting:

```elixir
DalaDev.Error.format(:adb_not_found)
# Returns: "adb not found — install Android platform-tools"

DalaDev.Error.format(:xcodebuild_failed, output: "CODE_SIGNING_REQUIRED")
# Returns: "xcodebuild failed: CODE_SIGNING_REQUIRED\nHint: Run mix dala.provision"
```

**iOS xcodebuild Diagnostics** (`DalaDev.Provision.diagnose_xcodebuild_failure/1`):

Pattern matches Apple's cryptic errors into actionable hints:

```elixir
DalaDev.Provision.diagnose_xcodebuild_failure("CODE_SIGNING_REQUIRED")
# Returns:
# %{
#   original: "CODE_SIGNING_REQUIRED",
#   hint: "No provisioning profile found. Run mix dala.provision first.",
#   fix: "mix dala.provision"
# }
```

### Configuration

**Module**: `DalaDev.Config`

Reads from `dala.exs` in the project root:

```elixir
# dala.exs
config :dala_dev,
  dala_dir: "/path/to/dala",
  bundle_id: "com.example.myapp",
  beam_flags: "-S 1:1 -sbwt none",
  liveview_port: 4000
```

Also supports environment variables:
- `DALA_CACHE_DIR` — Override OTP cache location (default: `~/.dala/cache/`)

---

## Cross-Cutting Concerns

### OTP Management

**Caching Strategy**:
- Pre-built tarballs cached in `~/.dala/cache/`
- Reused across all Dala projects on the machine
- Schema versioning (not OTP hash) for cache invalidation

**Schema Version Bump** (when tarball structure changes):

```elixir
# In DalaDev.OtpDownloader.valid_otp_dir?/2
def valid_otp_dir?(dir, schema_version) do
  # Bump this when you change tarball structure:
  current_schema = 3

  if schema_version != current_schema do
    false  # Cache invalid, re-download
  else
    # Check tarball contents...
  end
end
```

### Device ID Resolution

**Problem**: Multiple identifiers for the same device (serial, UDID, display ID).

**Solution**: `DalaDev.Device` provides consistent accessors:

```elixir
%DalaDev.Device{serial: "emulator-5554", platform: :android}
|> DalaDev.Device.display_id()
# Returns: "emulator-5554"

%DalaDev.Device{serial: "abc123...", platform: :ios}
|> DalaDev.Device.display_id()
# Returns: "abc123de" (first 8 hex chars, dashes removed)
```

**Matching**: `DalaDev.Device.match_id?/2` handles all ID formats:

```elixir
device = %DalaDev.Device{serial: "emulator-5554", ...}
DalaDev.Device.match_id?(device, "emulator-5554")  # true
DalaDev.Device.match_id?(device, "5554")           # true (partial match)
```

### Platform-Specific Logic

**macOS-only features**:

```elixir
defp macos? do
  match?({:unix, :darwin}, :os.type())
end

if macos?() do
  # iOS provisioning, simctl, etc.
else
  # Skip iOS features, show hint
end
```

**Graceful degradation**:
- If `adb` not found: Skip Android features, print hint
- If `xcrun` not found: Skip iOS features, print hint
- If `libimobiledevice` not installed: Skip physical iOS device features

---

## Gotchas and Operational Considerations

(Detailed in [AGENTS.md](AGENTS.md#gotchas-and-common-pitfalls))

### 1. Compile-time Regex Literals

**Problem**: Regex literals in module attributes compile at compile time, causing issues with OTP 28.0+.

**Solution**: Use runtime compilation:

```elixir
# ❌ DON'T
@pattern ~r/foo.*bar/

# ✅ DO
@pattern Regex.compile!("foo.*bar", "")
```

### 2. Device ID Resolution

Always use `DalaDev.NativeBuild.narrow_platforms_for_device/2` when resolving device IDs. Bypassing it causes:
- Spurious "No device matched" warnings
- Building for wrong platform

### 3. Xcodebuild Error Diagnostics

Update `DalaDev.Provision.diagnose_xcodebuild_failure/1` when encountering new Apple error strings.

### 4. OTP Tarball Schema Versioning

- **DO NOT** bump OTP hash for cache invalidation
- **DO** bump schema version in `valid_otp_dir?/2`

### 5. Release Script Assumptions

`scripts/release/` scripts assume `~/code/otp` exists with cross-compile output.

---

## References

- [AGENTS.md](../AGENTS.md) — Developer guide, gotchas, public API seams
- [Dala Commands Guide](dala_commands.md) — All `mix dala.*` commands with usage and internals
- [build_release.md](../build_release.md) — OTP cross-compilation walkthrough
- [README.md](../README.md) — Project overview, quick command reference
- [publishing_to_testflight.md](publishing_to_testflight.md) — iOS TestFlight publishing
