# AGENTS.md — dala_dev

You're in **dala_dev**, the build/deploy/devices toolkit for the dala ecosystem. This repository contains Mix tasks and supporting modules that handle:
- Building and deploying Elixir/OTP applications to mobile devices
- Discovering and managing connected Android and iOS devices
- Running emulators and simulators
- Provisioning development certificates and profiles
- Cross-compiling OTP releases for mobile platforms

**Important**: Read [`~/code/dala/docs/reference/AGENTS.md`](../dala/docs/reference/AGENTS.md) first for the system-wide view, the three-repo topology (dala, dala_dev, dala_new), and the cross-cutting pre-empt-failure rules that apply across all repositories. The notes below are dala_dev-specific conventions and gotchas.

## What this repo is

This repository provides the command-line tooling and library code for mobile development workflows with Elixir/OTP.

**Dual licensed under:**
- **MIT License** (for original Mob project portions) - see [LICENSE](LICENSE)
- **Apache License 2.0** (for new contributions) - see [LICENSE-APACHE](LICENSE-APACHE)

See [NOTICE](NOTICE) for attribution details.

### Mix Tasks (User-facing commands)

These are the commands users run via `mix dala.<task>`:

**Deployment and connection**:
- **`mix dala.deploy`** — Deploy builds to connected devices or emulators
- **`mix dala.push`** — Hot-push changed modules to running devices (no restart)
- **`mix dala.connect`** — Connect to a running device/emulator session
- **`mix dala.watch`** — Auto-push BEAMs on file save
- **`mix dala.watch_stop`** — Stop a running watch session

**Device management**:
- **`mix dala.devices`** — List discovered Android and iOS devices
- **`mix dala.emulators`** — Manage and launch emulators/simulators
- **`mix dala.screen`** — Capture screenshots, record video, preview screen

**Build and release**:
- **`mix dala.release`** — Build a signed iOS .ipa for App Store / TestFlight
- **`mix dala.release.android`** — Build a signed Android .aab for Google Play
- **`mix dala.publish`** — Upload .ipa to App Store Connect / TestFlight
- **`mix dala.publish.android`** — Upload .aab to Google Play Console

**Project setup**:
- **`mix dala.install`** — First-run setup: download OTP runtime, generate icons, write `dala.exs`
- **`mix dala.enable`** — Enable optional Dala features (camera, photo_library, etc.)
- **`mix dala.icon`** — Regenerate app icons from a source image
- **`mix dala.cache`** — Show or clear machine-wide caches
- **`mix dala.doctor`** — Diagnose common setup and configuration issues
- **`mix dala.provision`** — Handle iOS provisioning profiles and certificates
- **`mix dala.routes`** — Validate navigation destinations across the codebase

**Development tools**:
- **`mix dala.server`** — Start dev dashboard (Phoenix, localhost:4040)
- **`mix dala.web`** — Start comprehensive web UI for all dala_dev features
- **`mix dala.gen.live_screen`** — Generate a LiveView + Dala.Screen pair
- **`mix dala.debug`** — Interactive debugging for dala nodes
- **`mix dala.observer`** — Web-based Observer for remote node monitoring
- **`mix dala.logs`** — Collect and stream logs from devices and cluster nodes
- **`mix dala.trace`** — Distributed tracing for dala clusters
- **`mix dala.bench`** — Run performance benchmarks on dala nodes

**Battery benchmarking**:
- **`mix dala.battery_bench_android`** — Android battery benchmarking
- **`mix dala.battery_bench_ios`** — iOS battery benchmarking

### Core Modules (Library code)

- **`DalaDev.Discovery.Android`** — Discovers Android devices via `adb`, parses device listings
- **`DalaDev.Discovery.IOS`** — Discovers iOS simulators and devices via `xcrun simctl` and `devicectl`
- **`DalaDev.NativeBuild`** — Cross-compilation logic for Android (arm64/arm32) and iOS (simulator/device)
- **`DalaDev.OtpDownloader`** — Downloads and caches pre-built OTP tarballs for mobile platforms
- **`DalaDev.Deployer`** — Handles the deployment pipeline: build → package → install → launch
- **`DalaDev.HotPush`** — Hot-pushes changed BEAM modules via RPC (no restart)
- **`DalaDev.Emulators`** — Manages emulator lifecycle and configuration
- **`DalaDev.Connector`** — Discovery → tunnel → restart → connect orchestration
- **`DalaDev.Tunnel`** — Port tunneling (adb forward/reverse, iproxy)
- **`DalaDev.Device`** — Unified device struct with common interface
- **`DalaDev.Config`** — Configuration handling (dala.exs)
- **`DalaDev.Utils`** — Centralized utility functions (regex compilation, ADB helpers)
- **`DalaDev.Paths`** — Path resolution for OTP runtimes, SDKs, and build artifacts
- **`DalaDev.CrashDump`** — Crash dump parsing and HTML report generation
- **`DalaDev.Benchmark`** — Performance benchmarking utilities
- **`DalaDev.Profiling`** — Profiling and flame graph generation
- **`DalaDev.Tracing`** — Distributed tracing infrastructure
- **`DalaDev.Network`** — Network diagnostics and device connectivity
- **`DalaDev.LogCollector`** — Log collection and streaming from devices
- **`DalaDev.ScreenCapture`** — Screenshot and video capture from devices
- **`DalaDev.Debugger`** — Interactive remote debugging
- **`DalaDev.Observer`** — Remote node observation (web-based :observer)
- **`DalaDev.QR`** — QR code generation for device connectivity

### Release Engineering (`scripts/release/`)

The **release tooling** directory contains shell scripts that:
1. Cross-compile OTP for target platforms:
   - Android arm64 and arm32 (using NDK toolchain)
   - iOS simulator (x86_64 and arm64)
   - iOS device (arm64)
2. Stage compiled tarballs with metadata
3. Upload releases to GitHub Releases

**Patches for OTP**: iOS device builds require source patches in `scripts/release/patches/`:
- `forker_start` skip — Avoids fork issues on iOS
- EPMD `NO_DAEMON` guard — Prevents EPMD daemonization on iOS

See `build_release.md` for the complete release walkthrough with step-by-step instructions.

## Test-Driven Development (TDD)

TDD is the standard practice in this repository. This ensures reliability across platforms and makes refactoring safer.

### Testing Strategy

- **Write tests first**: Before implementing a new function or fixing a bug, write a test that captures the expected behavior
- **Test alongside code**: For simple changes, write tests in the same working session
- **Every function needs tests**: Public API functions, parsing logic, and platform-specific code paths all need coverage
- **Keep the suite green**: All tests must pass before merging. A failing test is a blocker.

### Running Tests

```bash
# Run the full test suite
mix test

# Run only unit tests (skip integration tests that need devices)
mix test --exclude integration

# Run a specific test file
mix test test/path/to/test_file.exs

# Run tests matching a pattern
mix test --only describe:"feature name"
```

### Integration Tests

Integration tests (tagged with `@tag :integration`) require connected devices or running emulators. These are excluded by default in CI and during development unless explicitly enabled.

## Gotchas and Common Pitfalls

These are issues that have caused problems in the past. Learn from our mistakes to avoid wasting time debugging them again.

### 1. Compile-time Regex Literals (Elixir 1.19 / OTP 28.0+)

**Problem**: Regex literals in module attributes or function heads are compiled at compile time, which can cause issues with certain OTP versions. OTP 28.0 removed `:re.import/1` which compile-time `~r//` literals depend on.

**Solution**: Always use runtime compilation with `Regex.compile!("...", "flags")` or `DalaDev.Utils.compile_regex/2` for dynamic or potentially problematic patterns.

**Status**: Already fixed in 0.3.17, but easy to reintroduce. 71 literals were swept in that release. Don't use `~r{...}` syntax for patterns that might be problematic.

```elixir
# ❌ DON'T — compile-time regex
@pattern ~r/foo.*bar/

# ✅ DO — runtime compilation
@pattern Regex.compile!("foo.*bar", "")

# ✅ DO — centralized utility
@pattern DalaDev.Utils.compile_regex("foo.*bar")
```

### 2. Device ID Resolution in `mix dala.deploy`

**Problem**: When deploying with `--device <id>`, the system must resolve the device ID through discovery before deciding which platform to build for.

**Key function**: `DalaDev.NativeBuild.narrow_platforms_for_device/2`

**Why it matters**: This function is the **single source of truth** for both:
- Determining build targets (which platforms to compile for)
- Validating deployment targets (which devices are valid)

**Consequence of bypassing**: If you skip this function:
- Deploy: You'll get spurious "No device matched" warnings
- Build: You'll build for the wrong platform (e.g., building iOS when you need Android)

**Rule**: Always call `narrow_platforms_for_device/2` when resolving device IDs.

### 3. Xcodebuild Error Diagnostics

**Problem**: `xcodebuild` produces cryptic error messages that are hard to interpret.

**Solution**: `DalaDev.Provision.diagnose_xcodebuild_failure/1` rewrites Apple's errors into actionable hints.

**How it works**:
- Takes raw `xcodebuild` output
- Pattern matches against known error strings
- Returns a structured hint with:
  - Apple's original error text (preserved for Google-ability)
  - Our human-friendly explanation
  - Suggested fix actions

**When to update**: Whenever you encounter a new Apple error string that isn't handled, add a new pattern match in `diagnose_xcodebuild_failure/1`.

### 4. OTP Tarball Schema Versioning

**Problem**: When we change the structure of OTP tarballs (e.g., adding new files, changing directory layout), cached downloads become invalid.

**Solution**: Bump the schema version in `DalaDev.OtpDownloader.valid_otp_dir?/2`.

**Important**: 
- **DO NOT** bump the OTP hash — that's for checksum verification
- **DO** bump the schema version — that's the knob for invalidating caches

**How it works**: `valid_otp_dir?/2` checks if a cached tarball matches the expected schema version. If the schema changes, the cache is invalidated and the tarball is re-downloaded.

### 5. Release Script Assumptions

**Problem**: The release scripts in `scripts/release/` assume a specific directory structure.

**Key assumption**: `~/code/otp` must exist with the correct cross-compile output.

**Patch application**: The patches in `scripts/release/patches/` are applied automatically by `xcompile_ios_device.sh`.

**Idempotency**: The patch application is idempotent — re-running the script is safe and won't cause issues.

**Setup**: If you're setting up a release build environment:
```bash
mkdir -p ~/code/otp
# Follow instructions in build_release.md for populating this directory
```

### 6. Default Arguments Evaluate Eagerly

**Problem**: `System.get_env("ROOTDIR", Path.expand("~/..."))` evaluates `Path.expand` *every call*, regardless of whether `ROOTDIR` is set. `Path.expand("~/...")` calls `System.user_home!()` which raises on Android (no `HOME` env var).

**Solution**: Use `case System.get_env(...)` or `||` instead.

```elixir
# ❌ DON'T — eager evaluation
System.get_env("ROOTDIR", Path.expand("~/otp"))

# ✅ DO — lazy evaluation
System.get_env("ROOTDIR") || Path.expand("~/otp")
```

**Reference**: Burned us once — see dala commit `d77932e`.

### 7. iOS Device Sandbox Blocks `fork()`

**Problem**: The BEAM's `forker_start` and EPMD's `run_daemon` both call fork, which is blocked by the iOS device sandbox.

**Solution**: Both are patched in our OTP cross-compile. Patches at `scripts/release/patches/`.

**Rule**: Don't undo them. These patches are essential for iOS device builds.

### 8. iOS Sim and iOS Device Are Different Build Paths

**Problem**: Sim → `ios/build.sh` (`build_ios/1` in NativeBuild). Device → `ios/build_device.sh` (`build_ios_physical/2`). These are completely different build chains.

**Solution**: When `--device <udid>` is passed, dala_dev resolves it via `IOS.list_devices/0` to know which path to take.

**Rule**: Don't shortcut — always go through device resolution to pick the right build path.

### 9. LV Port 4200 Is Global Per Device

**Problem**: Two installed Dala LV apps + one running = the second can't bind.

**Workaround**: Force-stop the squatter.

**Tracked**: `issues.md` #4 (hash bundle id into port).

### 10. `:dala_nif.log/1` for Early Startup Logging

**Problem**: `Logger` output goes to stderr and is invisible before `Dala.App.start` runs `Dala.Platform.NativeLogger.install()` (which reroutes Logger to NSLog/logcat).

**Solution**: Use `:dala_nif.log("message")` for diagnostics during early init (steps 1–4 in the Erlang bootstrap).

**Rule**: `:dala_nif.log/1` for early startup, `Logger` after `Dala.App.start`.

### 11. Android Distribution Startup Race

**Problem**: Android cannot start distribution at BEAM launch — races with hwui thread pool cause SIGABRT via FORTIFY `pthread_mutex_lock on destroyed mutex`.

**Solution**: `Dala.Connectivity.Dist.ensure_started/1` defers `Node.start/2` by 3 seconds after app startup. This is handled in the dala library.

**Also**: ERTS helper binaries (`erl_child_setup`, `inet_gethost`, `epmd`) cannot be exec'd from the app data directory (SELinux `app_data_file` blocks `execute_no_trans`). They are packaged in the APK as `lib*.so` in `jniLibs/arm64-v8a/` (gets `apk_data_file` label, which allows exec). `dala_beam.c` symlinks `BINDIR/<name>` → `<nativeLibraryDir>/lib<name>.so` before `erl_start`.

### 12. EPMD Tunneling Differences

**Problem**: iOS simulator and Android have different tunneling requirements.

**iOS simulator**: Shares the Mac's network stack — the iOS BEAM registers directly in the Mac's EPMD on port 4369. No forwarding needed.

**Android**: Separate network namespace. `dala_dev` sets up adb tunnels automatically:
```
adb reverse tcp:4369 tcp:4369   # EPMD: device → Mac (Android BEAM registers in Mac EPMD)
adb forward tcp:9100 tcp:9100   # dist:  Mac → device
```

**Port assignment**: Devices are assigned dist ports by index to avoid conflicts:
- Device 0 (Android): port 9100
- Device 1 (iOS sim): port 9101

### 13. Android Node Naming

**Problem**: Android node names include a serial suffix to distinguish multiple devices.

**Convention**:
- iOS simulator: `dala_demo_ios@127.0.0.1`
- Android: `dala_demo_android_<serial-suffix>@127.0.0.1`

**Note**: The serial suffix comes from `ro.serialno`. Multi-Android support is still pending — `MainActivity.java` does NOT yet read the `dala_dist_port` intent extra.

### 14. Struct Fields Used in Guards/Pattern-Matching Must Be Initialized

**Problem**: If a struct defines a field but doesn't set a default, code that accesses it with `socket.__dala__.changed` will fail when the field is missing.

**Solution**: Always initialize all fields in the struct definition, not just in constructor functions.

**Reference**: Burned us in `Dala.Ui.Socket` where `:changed` was only set in `new/2`.

### 15. Multi-Repo Changes Batch Together

**Problem**: A user-visible fix in dala often needs matching changes in dala_dev (build) and dala_new (template). Bumping versions without coordination produces ghost regressions.

**Rule**: Check all three repos before declaring done.

### 16. Dala Module Restructuring (Facade Pattern)

**Problem**: Dala's internal modules were restructured into sub-namespaces (e.g., `Dala.Renderer` → `Dala.Ui.Renderer`, `Dala.Socket` → `Dala.Ui.Socket`, `Dala.NativeLogger` → `Dala.Platform.NativeLogger`).

**Solution**: Top-level facade modules still exist and delegate to the new locations. Use the **facade module names** (`Dala.Screen`, `Dala.Socket`, `Dala.Renderer`, etc.) for public API calls — they still work. Use the **new sub-namespace paths** when referencing internal implementation details.

**Key mappings**:
- `Dala.App` → `Dala.App.App` (implementation)
- `Dala.Screen` → `Dala.Screen.Screen` (implementation)
- `Dala.Renderer` → `Dala.Ui.Renderer`
- `Dala.Socket` → `Dala.Ui.Socket`
- `Dala.Component` → `Dala.Ui.NativeView`
- `Dala.ComponentServer` → `Dala.Ui.NativeView.Server`
- `Dala.ComponentRegistry` → `Dala.Ui.NativeView.Registry`
- `Dala.Diff` → `Dala.Ui.Diff`
- `Dala.Node` → `Dala.Ui.Node`
- `Dala.List` → `Dala.Ui.List`
- `Dala.Style` → `Dala.Ui.Style`
- `Dala.Native` → `Dala.Platform.Native`
- `Dala.NativeLogger` → `Dala.Platform.NativeLogger`
- `Dala.Dist` → `Dala.Connectivity.Dist`
- `Dala.WiFi` → `Dala.Connectivity.Wifi`
- `Dala.Device` → `Dala.Device.Device`
- `Dala.Bluetooth` → `Dala.Hardware.Bluetooth`
- `Dala.Haptic` → `Dala.Hardware.Haptic`
- `Dala.Scanner` → `Dala.Hardware.Scanner`
- `Dala.Biometric` → `Dala.Hardware.Biometric`
- `Dala.Camera` → `Dala.Media.Camera`
- `Dala.Audio` → `Dala.Media.Audio`
- `Dala.Photos` → `Dala.Media.Photos`
- `Dala.PubSub` → `Dala.Platform.Pubsub`
- `Dala.Event` → `Dala.Event.Event`
- `Dala.LiveView` → `Dala.Platform.LiveView`
- `Dala.WebView` → `Dala.Ui.Embedded.Webview`
- `Dala.Motion` → `Dala.Ui.Sensor.Motion`
- `Dala.Alert` → `Dala.Ui.Feedback.Alert`
- `Dala.Theme.set/1` → `Dala.Theme.Theme.set/1`

**Rule**: When writing new code in dala_dev that references dala internals, use the new sub-namespace paths. When generating code for user projects (templates), use the facade names.

### 17. UI Render Path: Binary Protocol

**Problem**: The render pipeline now uses a custom binary protocol instead of JSON.

**Architecture**: `Dala.Ui.Renderer.render/4` encodes `Dala.Ui.Node` trees to compact binary → `Dala.Native.set_root_binary/1` NIF receives binary data.

**Binary format**: `[0xDA][0xA1][u16 version=3][u16 flags][u64 node_count] + nodes`
**Patches**: `[0xDA][0xA1][u16 version=3][u16 patch_count] + [FRAME_BEGIN][opcodes...][FRAME_END]`

**Zero-copy**: Rustler's `Binary<'a>` maps directly to BEAM off-heap binaries.

### 18. Skip Renders When Nothing Changed

**Problem**: Unnecessary renders waste CPU and cause flicker.

**Solution**: `Dala.Ui.Socket.assign/3` tracks changed keys in `__dala__.changed`. `Dala.Screen.Screen.do_render/3` skips the render if no assigns changed and no navigation occurred. `do_render/3` clears `changed` even when skipping render, preventing stale change tracking.

### 19. Incremental Rendering with Diff Engine

**Problem**: Full tree re-renders are expensive.

**Solution**: `Dala.Ui.Diff.diff/2` compares two `Dala.Ui.Node` trees and produces patches (`:replace`, `:update_props`, `:insert`, `:remove`). `Dala.Ui.Renderer.render_patches/5` sends only patches to native when supported. Falls back to full render if native doesn't support `apply_patches/1`.

### 20. Spark DSL for Declarative Screens

**Problem**: Writing `render/1` by hand is verbose.

**Solution**: `use Dala.Spark.Dsl` provides a declarative DSL that mirrors `Dala.Ui.Widgets` one-to-one. Features `@ref` syntax for assigns, auto-generated `mount/3`, and compile-time verifiers.

### 21. Zero-Config ML on iOS/Android

**Problem**: ML configuration is platform-specific and error-prone.

**Solution**: `Dala.ML.setup/0` auto-configures the ML stack:
- iOS device: EMLX with Metal GPU, JIT disabled (W^X policy)
- iOS simulator: EMLX with Metal GPU, JIT enabled
- Android: Nx.BinaryBackend

CoreML predictions are synchronous (NIF captures ObjC callback via Mutex) and run on the dirty CPU scheduler.

### 22. Bluetooth/WiFi Setup

**Problem**: Bluetooth and WiFi permissions setup is platform-specific and tedious.

**Solution**: `mix dala.setup_bluetooth_wifi` simplifies setup. Runtime helpers: `Dala.Setup.check_bluetooth/0`, `Dala.Setup.check_wifi/0`, `Dala.Setup.diagnostic/0`.

## Public API Seams (Testing Interfaces)

These functions are intentionally public to enable thorough testing. They serve as "seams" where we can inject test data and verify behavior in isolation.

**⚠️ Warning**: Do **NOT** make these functions private. They are public by design to support our testing strategy.

### Why These Are Public

Many of these functions contain parsing logic or platform-specific narrowing logic that needs to be tested independently of the full deployment pipeline. By keeping them public:
- We can test parsers with known input/output pairs
- We can test platform narrowing without needing actual devices
- We can verify error handling without triggering real deployments

### Discovery and Parsing

**Android device discovery**:
- `DalaDev.Discovery.Android.parse_devices_output/1` — Parses `adb devices -l` output

**iOS device/simulator discovery**:
- `DalaDev.Discovery.IOS.parse_simctl_json/1` — Parses `xcrun simctl list -j` JSON output
- `DalaDev.Discovery.IOS.parse_simctl_text/1` — Parses text output from simctl
- `DalaDev.Discovery.IOS.parse_runtime_version/1` — Extracts iOS runtime version info

### Build and Platform Logic

**Native build utilities**:
- `DalaDev.NativeBuild.narrow_platforms_for_device/2` — Determines which platforms to build for based on device
- `DalaDev.NativeBuild.ios_toolchain_available?/0` — Checks if iOS cross-compile toolchain is installed
- `DalaDev.NativeBuild.read_sdk_dir/1` — Reads SDK directory paths from configuration

### OTP Management

**OTP downloader**:
- `DalaDev.OtpDownloader.valid_otp_dir?/2` — Validates cached OTP tarballs against schema version
- `DalaDev.OtpDownloader.ios_device_extras_present?/1` — Checks for required iOS device extras in OTP

### Emulator Management

**Emulator utilities**:
- `DalaDev.Emulators.parse_simctl_json/1` — Parses simulator list JSON
- `DalaDev.Emulators.find_emulator_binary/1` — Locates emulator executables

### Provisioning and Diagnostics

**Error diagnosis**:
- `DalaDev.Provision.diagnose_xcodebuild_failure/1` — Translates xcodebuild errors into actionable hints

### Crash Analysis

**Crash dump utilities**:
- `DalaDev.CrashDump.parse/1` — Parses crash dump strings
- `DalaDev.CrashDump.parse_file/1` — Parses crash dump files
- `DalaDev.CrashDump.summary/1` — Generates crash dump summaries
- `DalaDev.CrashDump.html_report/1` — Generates HTML reports from crash dumps

### Device and Tunnel

**Device utilities**:
- `DalaDev.Device.short_id/1` — Generates short device ID
- `DalaDev.Device.node_name/1` — Generates node name from device
- `DalaDev.Device.summary/1` — Generates device summary

**Tunnel management**:
- `DalaDev.Tunnel.dist_port/1` — Gets distribution port for device

### Hot-Push

**Hot-push deployment**:
- `DalaDev.HotPush.snapshot_beams/0` — Snapshots current BEAM files
- `DalaDev.HotPush.push_changed/2` — Pushes only changed BEAM files

### Configuration

**Config utilities**:
- `DalaDev.Config.bundle_id/0` — Resolves app bundle ID
- `DalaDev.Config.load_dala_config/0` — Reads dala.exs configuration

### Paths

**Path resolution**:
- `DalaDev.Paths.default_runtime_dir/0` — Default OTP runtime directory
- `DalaDev.Paths.ios_sim_runtime_dir/1` — iOS simulator runtime directory
- `DalaDev.Paths.project_uses_env_var_runtime?/1` — Checks if project uses env-var runtime path

### Utilities

**Shared utilities**:
- `DalaDev.Utils.compile_regex/2` — Centralized regex compilation
- `DalaDev.Utils.run_adb_with_timeout/2` — ADB command with timeout protection
- `DalaDev.Utils.parse_adb_devices_output/1` — Parses ADB devices output

### Monitoring and Observability

**Cluster visualization**:
- `DalaDev.ClusterViz.topology/0` — Returns cluster topology
- `DalaDev.ClusterViz.health_dashboard/0` — Returns health dashboard data
- `DalaDev.ClusterViz.process_distribution/0` — Shows process distribution across nodes
- `DalaDev.ClusterViz.liveview_flow/0` — Traces LiveView message flows

**Remote node observer**:
- `DalaDev.Observer.observe/2` — Observes a remote node
- `DalaDev.Observer.system_info/2` — Gets system info from remote node
- `DalaDev.Observer.process_list/2` — Lists processes on remote node
- `DalaDev.Observer.ets_tables/2` — Lists ETS tables on remote node

### Performance Profiling

**Profiling utilities**:
- `DalaDev.Profiling.profile/3` — Runs a profiling session
- `DalaDev.Profiling.analyze/1` — Analyzes profiling results
- `DalaDev.Profiling.flame_graph/2` — Generates flame graphs
- `DalaDev.Profiling.profile_locally/3` — Profiles code locally

### CI and Testing

**CI testing utilities**:
- `DalaDev.CITesting.run_suite/2` — Runs a CI test suite
- `DalaDev.CITesting.run_with_provisioning/2` — Runs tests with device provisioning
- `DalaDev.CITesting.generate_ci_report/2` — Generates CI reports

**A/B testing**:
- `DalaDev.ABTesting.run/2` — Runs an A/B test
- `DalaDev.ABTesting.analyze/1` — Analyzes A/B test results
- `DalaDev.ABTesting.generate_report/2` — Generates A/B test reports

### Release Utilities

**Android release build**:
- `Mix.Tasks.Dala.Release.Android.format_size/1` — Formats file sizes for release notes

---

**Remember**: If you make any of these private, every downstream test breaks loudly. But worse, you'll lose the ability to evolve the parsers safely through refactoring with test coverage.

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

## Maintaining This Document

This file is a living document that should evolve with the codebase. Keep it current to help future contributors (including yourself) avoid past mistakes.

### Related Documentation

- **[Beginner Step-by-Step Guide](guides/beginner_guide.md)** — Getting started with dala_dev from scratch
- **[Development Workflow Guide](guides/development_workflow.md)** — Running, updating, and debugging with dala_dev
- **[Release and Packaging Guide](guides/release_and_packaging.md)** — Building and distributing production apps
- **[Architecture Guide](guides/architecture.md)** — Complete technical reference for dala_dev architecture
- **[Dala Commands Guide](guides/dala_commands.md)** — Complete reference for all `mix dala.*` commands with detailed explanations
- **[README.md](README.md)** — Project overview, architecture, and quick command reference
- **[build_release.md](build_release.md)** — Release build walkthrough with step-by-step instructions
- **[~/code/dala/docs/reference/AGENTS.md](../dala/docs/reference/AGENTS.md)** — System-wide orientation and pre-empt-failure rules

### When to Update

Update this file in the **same commit** when you:
- Change repository conventions or workflows
- Add a new public API seam (add it to the list above)
- Discover a new gotcha or pitfall (add it to the "Gotchas" section)
- Change the testing strategy or requirements
- Add new Mix tasks or core modules
- Update the release process

### Why It Matters

- **Stale guidance is worse than none** — It leads contributors astray
- **Fresh documentation saves time** — Others won't repeat your mistakes
- **It's part of the code** — Treat documentation updates as seriously as code changes

### Review Checklist

Before merging a PR, verify:
- [ ] All new public functions are documented in the "Public API Seams" section
- [ ] New gotchas are captured in the "Gotchas" section
- [ ] Code examples are correct and copy-pasteable
- [ ] Links to other docs (like `build_release.md`) are still valid
