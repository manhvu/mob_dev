# AGENTS.md — dala_dev

You're in **dala_dev**, the build/deploy/devices toolkit for the dala ecosystem. This repository contains Mix tasks and supporting modules that handle:
- Building and deploying Elixir/OTP applications to mobile devices
- Discovering and managing connected Android and iOS devices
- Running emulators and simulators
- Provisioning development certificates and profiles
- Cross-compiling OTP releases for mobile platforms

**Important**: Read [`~/code/dala/AGENTS.md`](../dala/AGENTS.md) first for the system-wide view, the three-repo topology (dala, dala_dev, dala_deploy), and the cross-cutting pre-empt-failure rules that apply across all repositories. The notes below are dala_dev-specific conventions and gotchas.

## What this repo is

This repository provides the command-line tooling and library code for mobile development workflows with Elixir/OTP.

### Mix Tasks (User-facing commands)

These are the commands users run via `mix dala.<task>`:

- **`mix dala.deploy`** — Deploy builds to connected devices or emulators
- **`mix dala.connect`** — Connect to a running device/emulator session
- **`mix dala.devices`** — List discovered Android and iOS devices
- **`mix dala.emulators`** — Manage and launch emulators/simulators
- **`mix dala.provision`** — Handle iOS provisioning profiles and certificates
- **`mix dala.doctor`** — Diagnose common setup and configuration issues
- **`mix dala.battery_bench_*`** — Battery benchmarking utilities

### Core Modules (Library code)

- **`DalaDev.Discovery.Android`** — Discovers Android devices via `adb`, parses device listings
- **`DalaDev.Discovery.IOS`** — Discovers iOS simulators and devices via `xcrun simctl` and `devicectl`
- **`DalaDev.NativeBuild`** — Cross-compilation logic for Android (arm64/arm32) and iOS (simulator/device)
- **`DalaDev.OtpDownloader`** — Downloads and caches pre-built OTP tarballs for mobile platforms
- **`DalaDev.Deployer`** — Handles the deployment pipeline: build → package → install → launch
- **`DalaDev.Emulators`** — Manages emulator lifecycle and configuration

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

**Problem**: Regex literals in module attributes or function heads are compiled at compile time, which can cause issues with certain OTP versions.

**Solution**: Always use runtime compilation with `Regex.compile!("...", "flags")` for dynamic or potentially problematic patterns.

**Status**: Already fixed in 0.3.17, but easy to reintroduce. Don't use `~r{...}` syntax for patterns that might be problematic.

```elixir
# ❌ DON'T — compile-time regex
@pattern ~r/foo.*bar/

# ✅ DO — runtime compilation
@pattern Regex.compile!("foo.*bar", "")
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

### Monitoring and Observability (New)

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

## Maintaining This Document

This file is a living document that should evolve with the codebase. Keep it current to help future contributors (including yourself) avoid past mistakes.

### Related Documentation

- **[Architecture Guide](guides/architecture.md)** — Complete technical reference for dala_dev architecture
- **[Dala Commands Guide](guides/dala_commands.md)** — Complete reference for all `mix dala.*` commands with detailed explanations
- **[README.md](../README.md)** — Project overview, architecture, and quick command reference
- **[build_release.md](../build_release.md)** — Release build walkthrough with step-by-step instructions

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
