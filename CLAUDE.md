# dala_dev — Agent Instructions

**Read [`AGENTS.md`](AGENTS.md) first**, then [`~/code/dala/AGENTS.md`](../dala/AGENTS.md) for the system-wide view. This file provides Claude Code-specific workflow guidance that complements the general AGENTS.md documentation.

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

**Project generation**:
- `DalaDev.ProjectGenerator.assigns/1` — Generates template assignments
- `DalaDev.ProjectGenerator.generate/2` — Generates project from templates

**Icon generation**:
- `DalaDev.IconGenerator.android_sizes/0` — Returns Android icon sizes
- `DalaDev.IconGenerator.ios_sizes/0` — Returns iOS icon sizes
- `DalaDev.IconGenerator.generate_from_source/2` — Generates icons from source image

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
- `lib/dala_dev/device.ex` — Device struct definition + `node_name/1`, `short_id/1`, `summary/1`
- `lib/dala_dev/tunnel.ex` — ADB tunnel setup for device communication, `dist_port/1`
- `lib/dala_dev/connector.ex` — Discovery → tunnel → restart → wait → connect workflow

**Deployment**:
- `lib/dala_dev/deployer.ex` — Full BEAM push + app restart pipeline
- `lib/dala_dev/hot_push.ex` — BEAM snapshot + RPC push for hot code reloading

**Discovery**:
- `lib/dala_dev/discovery/android.ex` — ADB device discovery and parsing
- `lib/dala_dev/discovery/ios.ex` — xcrun simctl discovery and parsing

### Mix Tasks (User-Facing Commands)

**Deployment and connection**:
- `lib/mix/tasks/dala.deploy.ex` — `mix dala.deploy` for deploying builds
- `lib/mix/tasks/dala.push.ex` — `mix dala.push` for hot-pushing code
- `lib/mix/tasks/dala.connect.ex` — `mix dala.connect` for connecting to devices
- `lib/mix/tasks/dala.watch.ex` — `mix dala.watch` for watch-mode development

**Device management**:
- `lib/mix/tasks/dala.devices.ex` — `mix dala.devices` for listing devices

**Project generation**:
- `lib/mix/tasks/dala.new.ex` — `mix dala.new APP_NAME` for creating new projects
- `lib/dala_dev/project_generator.ex` — EEx template rendering for project generation
- `priv/templates/dala.new/` — EEx templates for generated project files

**Icon generation**:
- `lib/dala_dev/icon_generator.ex` — Robot avatar generation + platform icon resizing
- `lib/mix/tasks/dala.icon.ex` — `mix dala.icon [--source PATH]` for generating icons

### Development Server

- `lib/mix/tasks/dala.server.ex` — `mix dala.server` for local development dashboard
