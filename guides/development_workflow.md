# Development Workflow Guide

This guide covers how to run, update, and debug applications using `dala_dev` tooling in your daily development workflow.

## Prerequisites

Before starting, ensure you have:
- Elixir and Mix installed
- `dala_dev` dependency added to your project
- For iOS development: Xcode and Xcode command line tools
- For Android development: Android SDK and ADB tools
- A connected device or running emulator/simulator

**New to dala?** See the [Beginner Step-by-Step Guide](beginner_guide.md) first.

---

## Running Your App with dala_dev

### Quick Start

The fastest way to get your app running on a device:

```bash
# Deploy to the first available device/emulator
mix dala.deploy

# List available devices first
mix dala.devices

# Deploy to a specific device
mix dala.deploy --device <device_id>
```

### Development Mode with Hot Reloading

For active development with automatic code pushing:

```bash
# Start watch mode - automatically pushes BEAM changes on file save
mix dala.watch

# Watch mode with specific device
mix dala.watch --device <device_id>

# Stop watch mode when done
mix dala.watch_stop
```

### Connecting to a Running App

To connect to a deployed app for interactive development:

```bash
# Connect to any running dala app
mix dala.connect

# Connect to specific device
mix dala.connect --device <device_id>
```

Once connected, you'll have an IEx session on the device where you can:
- Call functions directly
- Inspect state
- Debug issues interactively

## Updating Your App

### Hot Pushing Changes

For quick updates without full redeployment:

```bash
# Push only changed BEAM files (no restart required)
mix dala.push

# Push to specific device
mix dala.push --device <device_id>
```

Hot push is ideal for:
- Quick iteration on business logic
- Fixing bugs without app restart
- Testing changes immediately

### Full Redeployment

When you need a complete rebuild:

```bash
# Full deploy rebuilds and reinstalls
mix dala.deploy

# Force reinstall even if version hasn't changed
mix dala.deploy --force
```

## Debugging with dala_dev

### Interactive Debugging

```bash
# Start interactive debugging session
mix dala.debug

# Debug specific node
mix dala.debug --node <node_name@host>
```

The debug session provides:
- Process inspection
- Message tracing
- State examination
- Breakpoint-style debugging

### Log Collection

```bash
# Stream logs from all devices
mix dala.logs

# Stream logs from specific device
mix dala.logs --device <device_id>

# Filter logs by level
mix dala.logs --level error

# Save logs to file
mix dala.logs --output debug.log
```

### Remote Observer

For advanced Erlang system introspection:

```bash
# Launch web-based observer for remote node
mix dala.observer

# Observe specific node
mix dala.observer --node <node_name@host>
```

The observer provides:
- Process tree visualization
- Memory usage analysis
- ETS table inspection
- Application supervision tree

### Distributed Tracing

```bash
# Start distributed tracing
mix dala.trace

# Trace specific modules
mix dala.trace --modules MyApp.Core,MyApp.Web

# Set trace duration
mix dala.trace --duration 60
```

### Crash Dump Analysis

When your app crashes, analyze the crash dump:

```bash
# Parse and summarize crash dump
mix dala.crash_dump analyze <dump_file>

# Generate HTML report
mix dala.crash_dump report <dump_file> --output report.html

# Open report in browser
open report.html
```

## Development Dashboard

For a comprehensive web UI:

```bash
# Start the development dashboard (localhost:4040)
mix dala.server

# Start full web UI with all features
mix dala.web
```

The dashboard provides:
- Device management
- Log streaming
- File watching controls
- Performance metrics
- Crash dump viewer

## Common Development Scenarios

### Scenario 1: Quick Bug Fix

```bash
# 1. Connect to running app
mix dala.connect --device <id>

# 2. Reproduce and diagnose issue in IEx

# 3. Fix code locally

# 4. Push changes
mix dala.push --device <id>

# 5. Verify fix in connected session
```

### Scenario 2: New Feature Development

```bash
# 1. Start watch mode
mix dala.watch --device <id>

# 2. Develop feature with automatic pushes

# 3. Test on device in real-time

# 4. When done, stop watch mode
mix dala.watch_stop
```

### Scenario 3: Performance Investigation

```bash
# 1. Start observer for overview
mix dala.observer --node <node>

# 2. Run benchmarks
mix dala.bench --duration 30

# 3. Profile specific code paths
mix dala.trace --modules MyApp.SlowModule

# 4. Generate flame graph
mix dala.profile --function "MyApp.SlowModule.slow_function/2"
```

## Device Management

### Listing and Selecting Devices

```bash
# List all connected devices and emulators
mix dala.devices
```

See [Beginner Guide](beginner_guide.md#step-3-connect-a-device-or-emulator) for device setup instructions.

### Managing Emulators

```bash
# List available emulators/simulators
mix dala.emulators

# Launch an emulator
mix dala.emulators launch "Pixel_6_API_33"

# Launch iOS simulator
mix dala.emulators launch "iPhone 14"

# Shutdown emulator
mix dala.emulators shutdown "Pixel_6_API_33"
```

## Screen Capture and Recording

```bash
# Take screenshot
mix dala.screen screenshot --device <id> --output screen.png

# Record video (30 seconds)
mix dala.screen record --device <id> --output demo.mp4 --duration 30

# Live screen preview (macOS only)
mix dala.screen preview --device <id>
```

## Diagnosing Issues

### Running Doctor

When things aren't working, run diagnostics:

```bash
# Diagnose common setup and configuration issues
mix dala.doctor
```

See [Beginner Guide](beginner_guide.md#step-2-initial-setup-with-dala_dev) for initial setup.

### Checking Configuration

```bash
# View current dala.exs configuration
mix dala.config show

# Validate configuration
mix dala.config validate
```

### Cache Management

```bash
# Show cache information
mix dala.cache show

# Clear OTP runtime cache
mix dala.cache clear otp

# Clear all caches
mix dala.cache clear all
```

## Best Practices

1. **Use watch mode during development** - It saves time with automatic pushes
2. **Connect for debugging** - IEx on the device is powerful for investigation
3. **Check logs early** - Stream logs when diagnosing issues
4. **Use short device IDs** - They're easier to type and remember
5. **Run doctor first** - When encountering issues, `mix dala.doctor` is your friend
6. **Keep dala_dev updated** - Regular updates bring fixes and features

## Next Steps

- See [Release and Packaging Guide](release_and_packaging.md) for building production apps
- See [Beginner Step-by-Step Guide](beginner_guide.md) for getting started from scratch
- Check `mix help dala` for all available commands
