# Beginner Step-by-Step Guide

This guide walks you through setting up and running your first dala mobile app from scratch. No prior mobile development experience required!

## What is dala?

dala is a toolkit that lets you build mobile apps using Elixir and OTP (Erlang VM). You write your app logic in Elixir, and dala packages it to run natively on iOS and Android devices.

**Three repositories work together:**
- **dala** - The core library (LiveView, native bridges, runtime)
- **dala_dev** - Development tools (what this guide covers)
- **dala_new** - Project templates and generators

## Prerequisites Checklist

Before starting, ensure you have:

### Required for Everyone
- [ ] **Elixir installed** - Run `elixir --version` (need 1.14+)
- [ ] **Mix installed** - Run `mix --version`

### For iOS Development (Mac only)
- [ ] **macOS** - iOS development requires macOS
- [ ] **Xcode installed** - From App Store
- [ ] **Xcode command line tools** - Run `xcode-select --install`
- [ ] **Apple Developer Account** (free is fine for device testing)

### For Android Development
- [ ] **Android SDK** - Install via Android Studio or command line
- [ ] **Android device or emulator** - Physical device recommended
- [ ] **ADB tools** - Should come with Android SDK

### Verify Your Setup

Run this to check your environment:

```bash
# Check Elixir
elixir --version

# Check if dala_dev is available (we'll install it next)
mix dala.doctor
```

## Step 1: Create Your First dala App

### Using the Project Generator

The easiest way to start is with `dala_new`:

```bash
# Install dala_new archive
mix archive.install hex dala_new

# Create a new dala project
mix dala.new my_first_app

# Navigate to your project
cd my_first_app
```

This creates a project structure like:

```
my_first_app/
├── lib/
│   └── my_first_app/
│       ├── application.ex      # App entry point
│       ├── live/              # LiveView modules
│       │   └── home_live.ex
│       └── screens/           # Mobile screens
│           └── home_screen.ex
├── config/
│   └── config.exs
├── dala.exs                   # dala configuration
└── mix.exs                    # Elixir project file
```

### Understanding the Structure

- **LiveView modules** (`lib/my_first_app/live/`) - Handle state and events
- **Screen modules** (`lib/my_first_app/screens/`) - Define the UI
- **dala.exs** - Configuration for mobile deployment
- **mix.exs** - Standard Elixir project configuration

## Step 2: Initial Setup with dala_dev

Now let's set up your project for mobile development:

### Run the Install Command

```bash
# This sets up everything you need
mix dala.install
```

The installer will:

1. **Download OTP runtime** - Pre-built Erlang VM for mobile
2. **Generate app icons** - Default icons (you can customize later)
3. **Create dala.exs** - Configuration file (if not exists)
4. **Verify toolchain** - Check your development environment

### What Gets Downloaded?

The installer downloads pre-built OTP (Open Telecom Platform) runtimes:

```
~/.dala/
└── runtimes/
    ├── ios-sim/
    │   └── otp.tar.gz
    ├── ios-device/
    │   └── otp.tar.gz
    └── android/
        └── otp.tar.gz
```

These are cached globally so future projects don't need to re-download.

### Verify Installation

```bash
# Check everything is set up correctly
mix dala.doctor
```

You should see something like:

```
✓ Elixir installed
✓ Mix available
✓ OTP runtime for iOS sim found
✓ OTP runtime for Android found
✓ ADB available (for Android)
✓ Xcode tools available (for iOS)
```

## Step 3: Connect a Device or Emulator

### Option A: Physical Android Device

1. **Enable Developer Options** on your Android device:
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times
   - Developer Options will appear in Settings

2. **Enable USB Debugging** in Developer Options

3. **Connect via USB** to your computer

4. **Authorize the connection** on your phone (allow USB debugging)

5. **Verify connection**:
   ```bash
   mix dala.devices
   ```
   
   You should see your device listed under "Android Devices".

### Option B: Android Emulator

```bash
# List available emulators
mix dala.emulators

# Launch an emulator
mix dala.emulators launch "Pixel_6_API_33"
```

### Option C: iOS Simulator (Mac only)

```bash
# List available simulators
mix dala.emulators

# Launch iOS simulator
mix dala.emulators launch "iPhone 14"
```

### Option D: Physical iOS Device

1. **Connect your iPhone** via USB
2. **Trust the computer** on your iPhone
3. **Verify connection**:
   ```bash
   mix dala.devices
   ```

## Step 4: Run Your App for the First Time

### Deploy to Device

```bash
# Deploy to the first available device
mix dala.deploy

# Or specify a device
mix dala.devices  # Note the device ID
mix dala.deploy --device <device_id>
```

### What Happens During Deploy?

1. **Compiles** your Elixir code to BEAM bytecode
2. **Packages** with the OTP runtime
3. **Installs** the app on your device
4. **Launches** the app

You should see your app launch on the device!

### First App Structure

The default app shows:
- A welcome message
- A counter button (LiveView in action!)
- Basic navigation

Tap the button - the counter updates instantly. That's LiveView working on your phone!

## Step 5: Make Your First Change

### Understanding Hot Push

Instead of redeploying the entire app, you can "hot push" just the changed code.

### Start Watch Mode

```bash
# Start watching for file changes
mix dala.watch

# Or with specific device
mix dala.watch --device <device_id>
```

### Make a Change

Open `lib/my_first_app/live/home_live.ex` in your editor and find the render function. Change some text:

```elixir
# Before
def render(assigns) do
  ~H"""
  <Text>Welcome to dala!</Text>
  """
end

# After
def render(assigns) do
  ~H"""
  <Text>Hello from my first dala app!</Text>
  """
end
```

Save the file. Watch mode will automatically push the change to your device. Check your phone - the text should update instantly!

### Stop Watch Mode

When done developing:
```bash
mix dala.watch_stop
```

## Step 6: Customize App Icons

### Generate New Icons

```bash
# Use a PNG image (1024x1024 recommended)
mix dala.icon path/to/icon.png

# Or use the default generator
mix dala.icon --default
```

This generates icons for:
- Android (various densities)
- iOS (all required sizes)
- App stores

### Icon Locations

After generation:
```
assets/
├── icon.png              # Your source icon
├── android/             # Android icons
│   ├── mipmap-hdpi/
│   ├── mipmap-mdpi/
│   └── ...
└── ios/                  # iOS icons
    ├── AppIcon60x60@2x.png
    ├── AppIcon60x60@3x.png
    └── ...
```

## Step 7: Enable Additional Features

dala supports optional native features. Enable them as needed:

```bash
# See available features
mix dala.enable --list

# Enable camera access
mix dala.enable camera

# Enable photo library
mix dala.enable photo_library

# Enable location services
mix dala.enable location

# Enable push notifications
mix dala.enable push
```

Each feature:
1. Updates `dala.exs` with required permissions
2. Adds necessary native code
3. Updates app configuration

## Step 8: Test on Multiple Devices

### List All Devices

```bash
mix dala.devices
```

Output example:
```
Android Devices:
  - emulator-5554 (Android 13, Pixel 6) [short: a1b2]
  - R32N42ABC (Samsung Galaxy S21) [short: c3d4]

iOS Simulators:
  - A1B2C3D4-1234 (iPhone 14) [short: e5f6]

iOS Devices:
  - 00008020-0012345 (iPhone 13) [short: g7h8]
```

### Deploy to Specific Device

```bash
# Use short ID for convenience
mix dala.deploy --device a1b2
```

## Step 9: Debugging Basics

### Connect to Running App

```bash
# Connect to device for interactive debugging
mix dala.connect --device <id>
```

You'll get an IEx prompt running **on the device**:

```elixir
# Now you're in IEx on the phone!
# Inspect app state
:sys.get_status(MyFirstApp.Live.HomeLive)

# Call functions
MyFirstApp.some_function()

# Exit with Ctrl+C twice
```

### View Logs

```bash
# Stream logs from device
mix dala.logs --device <id>

# Filter by level
mix dala.logs --level error
```

## Step 10: Build for Release (When Ready)

When you're ready to share your app:

### For Testing (Ad-hoc)

```bash
# iOS - for registered devices
mix dala.release --no-sign
mix dala.deploy --device <ios_device>

# Android - installable APK
mix dala.release.android --apk
adb install my_first_app.apk
```

### For App Stores

```bash
# iOS - App Store / TestFlight
mix dala.release
mix dala.publish --testflight

# Android - Google Play
mix dala.release.android
mix dala.publish.android --track beta
```

See the [Release and Packaging Guide](release_and_packaging.md) for details.

## Common Beginner Mistakes

### Mistake 1: Not Enabling Features Before Using Them

```bash
# Wrong: Using camera without enabling
# Your app will crash!

# Right: Enable first
mix dala.enable camera
# Then use in code
```

### Mistake 2: Forgetting to Stop Watch Mode

```bash
# Watch mode runs in background
# Always stop it when done
mix dala.watch_stop
```

### Mistake 3: Device Goes to Sleep

```bash
# Keep device awake during development
# Android: Settings → Developer Options → Stay Awake
# iOS Simulator: Hardware → Keep Screen Awake
```

### Mistake 4: Not Reading Error Messages

```bash
# If something fails, read the full output
# dala_dev provides actionable error messages

# Run doctor for diagnostics
mix dala.doctor
```

## Quick Reference Commands

```bash
# Setup
mix dala.new my_app          # Create new app
mix dala.install             # Initial setup
mix dala.icon path/to.png    # Generate icons

# Development
mix dala.devices             # List devices
mix dala.deploy              # Deploy to device
mix dala.watch               # Auto-push changes
mix dala.connect             # Interactive debugging

# Debugging
mix dala.logs                # View logs
mix dala.doctor              # Diagnose issues

# Release
mix dala.release             # Build for iOS
mix dala.release.android     # Build for Android
mix dala.publish             # Upload to stores
```

## Next Steps

Congratulations! You've built and deployed your first dala mobile app. Here's what to explore next:

1. **Learn LiveView** - The UI framework (see `dala` documentation)
2. **Explore Native Features** - Camera, GPS, notifications (`mix dala.enable --list`)
3. **Read Development Workflow** - [development_workflow.md](development_workflow.md)
4. **Prepare for Release** - [release_and_packaging.md](release_and_packaging.md)
5. **Join the Community** - Check dala project for community links

## Getting Help

- **Run doctor**: `mix dala.doctor` - Diagnoses common issues
- **Check logs**: `mix dala.logs` - See what's happening
- **Read docs**: `mix help dala` - All available commands
- **Project AGENTS.md**: For detailed technical information

Happy coding! 🚀
