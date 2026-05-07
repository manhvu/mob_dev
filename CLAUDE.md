# dala_dev — Agent Instructions

**Read [`AGENTS.md`](AGENTS.md) first**, then [`~/code/dala/docs/reference/AGENTS.md`](../dala/docs/reference/AGENTS.md) for the system-wide view. This file provides Claude Code-specific workflow guidance that complements the general AGENTS.md documentation.

> **Important**: Keep AGENTS.md up to date when you add a public API seam, change a convention, or discover a new gotcha. Update it in the **same commit** as your change — not a follow-up.

## Test-Driven Development (TDD)

TDD is the standard practice in this repository. Write tests before or alongside new code to ensure reliability.

### Testing Strategy

- **Write tests first**: Before implementing a new function or fixing a bug, write a test that captures the expected behavior
- **Every function needs tests**: Public API functions, parsing logic, and platform-specific code paths all need coverage
- **Keep the suite green**: All tests must pass before merging

### Running Tests

```bash
# Run all tests
mix test

# Run tests in watch mode (requires mix_test_watch dependency)
mix test --watch

# Run only unit tests (skip integration tests)
mix test --exclude integration

# Run a specific test file
mix test test/path/to/test_file.exs
```

## Pre-commit Checklist

Before committing changes, run **all three** in this order to ensure code quality:

```bash
# 1. Run the full test suite (call out any pre-existing flaky tests explicitly)
mix test

# 2. Apply Elixir formatting
mix format

# 3. Check code quality (address new issues; pre-existing ones are tracked separately)
mix credo --strict
```

**Note**: If `mix test` reveals pre-existing flaky tests, document them explicitly in your commit message.

## What to Test

### Always Testable (Pure Functions, No Hardware Required)

These functions can and should be tested without any external dependencies:

**Device utilities**:
- `DalaDev.Device` — `short_id/1`, `node_name/1`, `summary/1`

**Tunnel management**:
- `DalaDev.Tunnel` — `dist_port/1`

**Discovery and parsing**:
- `DalaDev.Discovery.Android.parse_devices_output/1` — Parses `adb devices -l` output
- `DalaDev.Discovery.IOS.parse_simctl_json/1` — Parses `xcrun simctl list -j` JSON
- `DalaDev.Discovery.IOS.parse_simctl_text/1` — Parses text output from simctl
- `DalaDev.Discovery.IOS.parse_runtime_version/1` — Extracts iOS runtime version

**Hot-push deployment**:
- `DalaDev.HotPush.snapshot_beams/0` — Snapshots current BEAM files
- `DalaDev.HotPush.push_changed/2` — Pushes only changed BEAM files

**Configuration**:
- `DalaDev.Config.bundle_id/0` — Resolves app bundle ID
- `DalaDev.Config.load_dala_config/0` — Reads dala.exs configuration

**Path resolution**:
- `DalaDev.Paths.default_runtime_dir/0` — Default OTP runtime directory
- `DalaDev.Paths.ios_sim_runtime_dir/1` — iOS simulator runtime directory
- `DalaDev.Paths.project_uses_env_var_runtime?/1` — Checks if project uses env-var runtime path

**Utilities**:
- `DalaDev.Utils.compile_regex/2` — Centralized regex compilation
- `DalaDev.Utils.run_adb_with_timeout/2` — ADB command with timeout protection
- `DalaDev.Utils.parse_adb_devices_output/1` — Parses ADB devices output

**Icon generation**:
- `DalaDev.IconGenerator.android_sizes/0` — Returns Android icon sizes
- `DalaDev.IconGenerator.ios_sizes/0` — Returns iOS icon sizes
- `DalaDev.IconGenerator.generate_from_source/2` — Generates icons from source image

**Crash dump utilities**:
- `DalaDev.CrashDump.parse/1` — Parses crash dump strings
- `DalaDev.CrashDump.parse_file/1` — Parses crash dump files
- `DalaDev.CrashDump.summary/1` — Generates crash dump summaries
- `DalaDev.CrashDump.html_report/1` — Generates HTML reports from crash dumps

**Provisioning and diagnostics**:
- `DalaDev.Provision.diagnose_xcodebuild_failure/1` — Translates xcodebuild errors into actionable hints

### Hardware-Dependent (Skip Gracefully When Devices Absent)

These tests require actual hardware or running emulators. Tag them with `@tag :integration` to exclude from default test runs:

**Android discovery**:
- `Discovery.Android.list_devices/0` — Requires `adb` + connected device

**iOS discovery**:
- `Discovery.IOS.list_simulators/0` — Requires `xcrun`

**Deployment**:
- `Deployer.deploy_all/1` — Requires running device

**Hot-push**:
- `HotPush.connect/1` — Requires running BEAM node

**How to tag integration tests**:
```elixir
@tag :integration
test "lists connected Android devices" do
  # test implementation
end
```

**Run only unit tests**: `mix test --exclude integration`

## Parsing Functions Are Public by Design

The following parsing functions are **intentionally public** to enable thorough testing:

- `parse_devices_output/1` — Parses ADB device listings
- `parse_simctl_json/1` — Parses iOS simulator JSON
- `parse_simctl_text/1` — Parses iOS simulator text output
- `parse_runtime_version/1` — Extracts iOS version information

**⚠️ Warning**: Do **NOT** make these functions private. They serve as "seams" for testing parsing logic with known inputs and expected outputs without requiring actual devices.

## Releasing a New OTP Runtime

When upgrading OTP, you need to rebuild the pre-built tarballs that `DalaDev.OtpDownloader` downloads. This ensures mobile platforms have the correct OTP runtime.

### Release Process

1. **Cross-compile OTP** for target platforms:
   - Android arm64 and arm32 (using NDK toolchain)
   - iOS simulator (x86_64 and arm64)
   - iOS device (arm64)

2. **Stage the tarballs** with metadata (version, platform, checksums)

3. **Upload to GitHub Releases** for distribution

4. **Update the hash** in `otp_downloader.ex` for checksum verification

**Full instructions**: See [`build_release.md`](build_release.md) for the complete step-by-step process, including patching OTP source for iOS device compatibility.

**Important**: Bump the schema version in `valid_otp_dir?/2` (not the OTP hash) when changing tarball structure to invalidate stale caches.

## Key Files and Their Purposes

### Core Modules

**Device management**:
- `lib/mob_dev/device.ex` — Device struct definition + `node_name/1`, `short_id/1`, `summary/1`
- `lib/mob_dev/tunnel.ex` — ADB tunnel setup for device communication, `dist_port/1`
- `lib/mob_dev/connector.ex` — Discovery → tunnel → restart → wait → connect workflow
- `lib/mob_dev/config.ex` — Configuration handling (dala.exs), bundle ID resolution
- `lib/mob_dev/paths.ex` — Path resolution for OTP runtimes, SDKs, and build artifacts
- `lib/mob_dev/utils.ex` — Centralized utilities (regex compilation, ADB helpers, format_bytes)
- `lib/mob_dev/error.ex` — Standardized error handling and formatting

**Deployment**:
- `lib/mob_dev/deployer.ex` — Full BEAM push + app restart pipeline
- `lib/mob_dev/hot_push.ex` — BEAM snapshot + RPC push for hot code reloading
- `lib/mob_dev/native_build.ex` — APK/.app bundle building and signing
- `lib/mob_dev/otp_downloader.ex` — Pre-built OTP runtime downloads and caching

**Discovery**:
- `lib/mob_dev/discovery/android.ex` — ADB device discovery and parsing
- `lib/mob_dev/discovery/ios.ex` — xcrun simctl discovery and parsing

**Observability**:
- `lib/mob_dev/crash_dump.ex` — Crash dump parsing and HTML reports
- `lib/mob_dev/debugger.ex` — Interactive remote debugging
- `lib/mob_dev/observer.ex` — Web-based :observer for remote nodes
- `lib/mob_dev/tracing.ex` — Distributed tracing infrastructure
- `lib/mob_dev/profiling.ex` — Profiling and flame graph generation
- `lib/mob_dev/log_collector.ex` — Log collection and streaming
- `lib/mob_dev/screen_capture.ex` — Screenshot and video capture
- `lib/mob_dev/network.ex` — Network diagnostics
- `lib/mob_dev/network_diag.ex` — Network diagnostic utilities

**Other**:
- `lib/mob_dev/emulators.ex` — Emulator lifecycle management
- `lib/mob_dev/qr.ex` — QR code generation
- `lib/mob_dev/release.ex` — Release build utilities
- `lib/mob_dev/icon_generator.ex` — Icon generation for Android/iOS
- `lib/mob_dev/enable.ex` — Feature enablement
- `lib/mob_dev/benchmark.ex` — Performance benchmarking

### Mix Tasks (User-Facing Commands)

**Deployment and connection**:
- `lib/mix/tasks/dala.deploy.ex` — `mix dala.deploy` for deploying builds
- `lib/mix/tasks/dala.push.ex` — `mix dala.push` for hot-pushing code
- `lib/mix/tasks/dala.connect.ex` — `mix dala.connect` for connecting to devices
- `lib/mix/tasks/dala.watch.ex` — `mix dala.watch` for watch-mode development
- `lib/mix/tasks/dala.watch_stop.ex` — Stop a running watch session

**Device management**:
- `lib/mix/tasks/dala.devices.ex` — `mix dala.devices` for listing devices
- `lib/mix/tasks/dala.screen.ex` — `mix dala.screen` for screenshots/video

**Build and release**:
- `lib/mix/tasks/dala.release.ex` — `mix dala.release` for iOS .ipa builds
- `lib/mix/tasks/dala.release.android.ex` — `mix dala.release.android` for Android .aab builds
- `lib/mix/tasks/dala.publish.ex` — `mix dala.publish` for TestFlight upload
- `lib/mix/tasks/dala.publish.android.ex` — `mix dala.publish.android` for Google Play upload

**Project setup**:
- `lib/mix/tasks/dala.install.ex` — `mix dala.install` for first-run setup
- `lib/mix/tasks/dala.enable.ex` — `mix dala.enable` for feature enablement
- `lib/mix/tasks/dala.icon.ex` — `mix dala.icon` for icon generation
- `lib/mix/tasks/dala.cache.ex` — `mix dala.cache` for cache management
- `lib/mix/tasks/dala.doctor.ex` — `mix dala.doctor` for diagnostics
- `lib/mix/tasks/dala.provision.ex` — `mix dala.provision` for iOS provisioning
- `lib/mix/tasks/dala.routes.ex` — `mix dala.routes` for navigation validation

**Development tools**:
- `lib/mix/tasks/dala.server.ex` — `mix dala.server` for dev dashboard
- `lib/mix/tasks/dala.web.ex` — `mix dala.web` for comprehensive web UI
- `lib/mix/tasks/dala.gen.live_screen.ex` — `mix dala.gen.live_screen` for LiveView+Screen generation
- `lib/mix/tasks/dala.debug.ex` — `mix dala.debug` for interactive debugging
- `lib/mix/tasks/dala.observer.ex` — `mix dala.observer` for web-based Observer
- `lib/mix/tasks/dala.logs.ex` — `mix dala.logs` for log collection
- `lib/mix/tasks/dala.trace.ex` — `mix dala.trace` for distributed tracing
- `lib/mix/tasks/dala.bench.ex` — `mix dala.bench` for performance benchmarks

**Battery benchmarking**:
- `lib/mix/tasks/dala.battery_bench_android.ex` — Android battery bench
- `lib/mix/tasks/dala.battery_bench_ios.ex` — iOS battery bench

### Development Server

- `lib/mob_dev/server/` — Phoenix-based dev dashboard
  - `endpoint.ex` — Phoenix endpoint
  - `router.ex` — Route definitions
  - `device_poller.ex` — Periodic device discovery
  - `watch_worker.ex` — File watch and auto-push
  - `log_streamer.ex` — Log streaming from devices
  - `log_buffer.ex` / `elixir_log_buffer.ex` — Log buffering
  - `elixir_logger.ex` — Elixir Logger forwarding
  - `log_filter.ex` — Log filtering
