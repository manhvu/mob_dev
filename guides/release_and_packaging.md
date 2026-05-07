# Release and Packaging Guide

This guide covers how to build, package, and distribute your dala apps for production on Android and iOS platforms.

## Overview

The release process involves:
1. **Building** - Cross-compiling OTP and your app for target platforms
2. **Packaging** - Creating signed .ipa (iOS) or .aab (Android) files
3. **Publishing** - Uploading to App Store Connect or Google Play Console

## Prerequisites for Release Builds

### General Requirements
- `dala_dev` installed and configured
- Valid `dala.exs` configuration file
- App icons generated (`mix dala.icon`)
- Required features enabled (`mix dala.enable`)

### iOS Release Requirements
- Apple Developer Account
- Valid provisioning profile and certificate
- Xcode with command line tools
- iOS OTP runtime (downloaded automatically or built manually)

### Android Release Requirements
- Android SDK (API level 21+)
- Keystore file for signing
- Android OTP runtime (downloaded automatically or built manually)

## Building OTP Runtimes

### Automatic OTP Download

`dala_dev` can automatically download pre-built OTP runtimes:

```bash
# Check current OTP runtime status
mix dala.cache show

# Download OTP for all platforms (first build will do this automatically)
mix dala.release
```

### Manual OTP Build (Advanced)

For custom OTP builds or when pre-built binaries don't work:

```bash
# Follow the detailed walkthrough in build_release.md
# This involves:
# 1. Setting up ~/code/otp directory
# 2. Running cross-compile scripts
# 3. Applying iOS patches if needed
```

See `build_release.md` for the complete manual build walkthrough.

## Building for iOS

### Building .ipa for App Store / TestFlight

```bash
# Build signed iOS .ipa
mix dala.release

# Build with specific configuration
mix dala.release --config prod

# Skip code signing (for testing on registered devices)
mix dala.release --no-sign
```

The build process:
1. Compiles your Elixir code for iOS arm64
2. Packages with OTP runtime
3. Creates .app bundle
4. Signs with provisioning profile
5. Exports as .ipa file

### iOS Provisioning

If you encounter provisioning issues:

```bash
# Diagnose provisioning problems
mix dala.provision diagnose

# List available certificates
mix dala.provision certificates

# List provisioning profiles
mix dala.provision profiles

# Fix common provisioning issues
mix dala.provision fix
```

### Understanding xcodebuild Errors

When `xcodebuild` fails, use the built-in diagnostics:

```bash
# The error output will include actionable hints
# Example: "Provisioning profile doesn't match bundle identifier"
# → Suggestion: Update bundle ID in dala.exs or create new profile
```

## Building for Android

### Building .aab for Google Play

```bash
# Build signed Android .aab (Android App Bundle)
mix dala.release.android

# Build APK instead of AAB (for side-loading)
mix dala.release.android --apk

# Build with specific flavor
mix dala.release.android --flavor production
```

The build process:
1. Compiles your Elixir code for Android (arm64/arm32)
2. Packages with OTP runtime
3. Creates APK/AAB
4. Signs with keystore

### Android Signing Configuration

Ensure your `dala.exs` has the correct signing config:

```elixir
# In dala.exs
config :dala, :android,
  keystore_path: "/path/to/keystore.jks",
  keystore_password: "your_keystore_password",
  key_alias: "your_key_alias",
  key_password: "your_key_password"
```

Or use environment variables:
```bash
export DALA_ANDROID_KEYSTORE_PATH=/path/to/keystore.jks
export DALA_ANDROID_KEYSTORE_PASSWORD=password
export DALA_ANDROID_KEY_ALIAS=alias
export DALA_ANDROID_KEY_PASSWORD=password
```

## Publishing to App Stores

### iOS: Upload to App Store Connect / TestFlight

#### Quick Publish

```bash
# Upload .ipa to App Store Connect
mix dala.publish

# Upload to specific platform
mix dala.publish --platform ios

# Skip package upload (if already built)
mix dala.publish --skip-build

# Upload to TestFlight only
mix dala.publish --testflight
```

#### Detailed TestFlight Setup (First-time)

For first-time TestFlight publishing, follow these one-time setup steps:

**1. Pick a real bundle ID**
```elixir
# In dala.exs
config :dala,
  bundle_id: "com.yourcompany.yourapp"  # Must be unique!
```

**2. Update bundle ID + display name**
```bash
# Edit dala.exs with your real bundle ID
mix dala.install  # Regenerate with new ID
```

**3. Register App ID at Apple**
- Go to [Apple Developer Portal](https://developer.apple.com)
- Certificates, Identifiers & Profiles → Identifiers → +
- Register your bundle ID

**4. Create Apple Distribution Certificate**
- Certificates → +
- Select "Apple Distribution"
- Download and install the certificate

**5. Create App Store Provisioning Profile**
- Profiles → +
- Select "App Store" distribution
- Download and install the profile

**6. Run provisioning helper**
```bash
mix dala.provision --distribution
```

**7. Create App Store Connect App Record**
- Go to [App Store Connect](https://appstoreconnect.apple.com)
- My Apps → +
- Create new app with your bundle ID

**8. Create App Store Connect API Key**
- App Store Connect → Users and Access → Keys
- Generate API key with "App Manager" role
- Save the key ID and issuer ID

**9. Configure dala.exs**
```elixir
config :dala, :app_store_connect,
  key_id: "your_key_id",
  issuer_id: "your_issuer_id",
  private_key_path: "/path/to/AuthKey_XXXXXX.p8"
```

#### Per-Release Flow

```bash
# 1. Ensure provisioning is up-to-date
mix dala.provision --distribution

# 2. Build the release
mix dala.release

# 3. Publish to TestFlight
mix dala.publish --testflight

# 4. Add testers in TestFlight (via App Store Connect web UI)
```

#### TestFlight Troubleshooting

**Build hangs during upload:**
```bash
# The publish command may appear to hang for several minutes
# This is normal - xcrun altool can be slow
# Be patient, it will complete
```

**Missing API key permissions:**
```bash
# Ensure you've downloaded the API key once from App Store Connect
# The "one-time download" warning must be acknowledged
# Otherwise you'll get authentication errors
```

**Provisioning profile errors:**
```bash
# Error: No profile for team 'X' matching 'profile name' found
# Solution: Run provisioning helper again
mix dala.provision --distribution

# Error: Distribution profile can't be auto-created for unregistered App ID
# Solution: Register App ID at developer.apple.com first
```

**App Store validation errors:**
The App Store validator may reject builds for these reasons:

1. **Standalone binaries in bundle** (Error 90171)
   - OTP runtime contains standalone binaries
   - Use the patched OTP build from dala_dev

2. **Test-harness uses private UIKit selectors** (Error 50)
   - Debug symbols in release build
   - Ensure you're building with MIX_ENV=prod

3. **Info.plist gaps** (Errors 90065/90507/90530)
   - Missing required keys in Info.plist
   - Run `mix dala.provision --distribution` to fix

4. **CodeResources symlink** (Error 90071)
   - Symlink issues in the bundle
   - Rebuild with `mix dala.release`

The publish process includes:
1. Validates .ipa file
2. Authenticates with App Store Connect
3. Uploads using `xcrun altool` or Transporter
4. Processes for TestFlight/App Store

### Android: Upload to Google Play Console

```bash
# Upload .aab to Google Play
mix dala.publish.android

# Upload to specific track
mix dala.publish.android --track production
mix dala.publish.android --track beta
mix dala.publish.android --track alpha
mix dala.publish.android --track internal

# Skip package upload (if already built)
mix dala.publish.android --skip-build
```

The publish process:
1. Authenticates with Google Play API
2. Uploads .aab to Play Console
3. Promotes to specified track

## Release Configuration

### dala.exs Configuration

Your `dala.exs` file controls release settings:

```elixir
# Example dala.exs
use Mix.Config

config :dala,
  app_name: "MyApp",
  bundle_id: "com.example.myapp",
  version: "1.0.0",
  version_code: 1

config :dala, :ios,
  team_id: "ABC123DEF",
  provisioning_profile: "MyApp Distribution",
  deployment_target: "14.0"

config :dala, :android,
  min_sdk: 21,
  target_sdk: 33,
  keystore_path: System.get_env("KEYSTORE_PATH")
```

### Environment-Specific Configs

```bash
# Build for different environments
MIX_ENV=prod mix dala.release
MIX_ENV=staging mix dala.release
```

## OTP Runtime Schema Versioning

Important: OTP tarball structure may change between releases.

```bash
# Check OTP cache validity
mix dala.cache show

# If you change OTP structure, bump schema version in:
# lib/dala_dev/otp_downloader.ex - valid_otp_dir?/2 function
```

**Note**: Bump schema version (not OTP hash) to invalidate caches when structure changes.

## Build Artifacts

After building, artifacts are stored in:

```
_build/
  ├── ios/
  │   ├── MyApp.ipa          # iOS release build
  │   └── MyApp.app/         # Unpacked app bundle
  └── android/
      ├── MyApp.aab          # Android App Bundle
      └── MyApp.apk          # Android APK (if built)
```

## Common Build Issues and Solutions

### Issue: "No iOS provisioning profile found"

```bash
# Solution: Run provisioning helper
mix dala.provision

# Or manually in Xcode:
# - Open Preferences → Accounts
# - Download provisioning profiles
# - Ensure bundle ID matches
```

### Issue: "Android keystore not found"

```bash
# Solution: Generate keystore
keytool -genkey -v -keystore myapp.keystore -alias myapp \
  -keyalg RSA -keysize 2048 -validity 10000

# Then update dala.exs with path
```

### Issue: "OTP runtime not found"

```bash
# Solution: Clear cache and rebuild
mix dala.cache clear otp
mix dala.release
```

### Issue: "xcodebuild failed with code 65"

```bash
# Use built-in diagnostics
mix dala.provision diagnose_xcodebuild_failure

# Common fixes:
# - Update provisioning profile
# - Check bundle ID matches
# - Ensure certificate is valid
```

### Issue: "Android build tools version mismatch"

```bash
# Solution: Update build tools in dala.exs
config :dala, :android,
  build_tools_version: "33.0.0"
```

## Release Script Reference

For advanced users, release scripts are in `scripts/release/`:

```
scripts/release/
├── xcompile_android.sh        # Android cross-compile
├── xcompile_ios_device.sh     # iOS device cross-compile
├── xcompile_ios_sim.sh        # iOS simulator cross-compile
└── patches/                   # OTP patches for iOS
    ├── forker_start.patch
    └── epmd_no_daemon.patch
```

These scripts:
- Cross-compile OTP for target platforms
- Apply necessary patches
- Stage tarballs with metadata
- Upload to GitHub Releases (when configured)

## Testing Release Builds

Before publishing, test your release builds:

### iOS Testing

```bash
# Install on connected device
mix dala.deploy --device <ios_device_id>

# Or use TestFlight for broader testing
mix dala.publish --testflight
```

### Android Testing

```bash
# Install APK on device
adb install -r _build/android/MyApp.apk

# Or upload to Internal Testing track
mix dala.publish.android --track internal
```

## Best Practices

1. **Test release builds locally** before publishing
2. **Use version codes** that increment with each release
3. **Keep keystore safe** - lost keystores cannot be recovered
4. **Test on multiple devices** - especially different OS versions
5. **Monitor crash reports** after release
6. **Use staged rollouts** for production releases
7. **Keep provisioning profiles updated** - they expire annually

## Automation

### CI/CD Integration

Example CI script:

```yaml
# .github/workflows/release.yml
- name: Build iOS Release
  run: |
    mix dala.release
    mix dala.publish --testflight

- name: Build Android Release
  run: |
    mix dala.release.android
    mix dala.publish.android --track beta
```

### Fastlane Integration

`dala_dev` can work alongside Fastlane:

```bash
# Build with dala
mix dala.release

# Upload with Fastlane
fastlane ios release
fastlane android release
```

## Troubleshooting

### Verbose Build Output

```bash
# Enable verbose output
mix dala.release --verbose

# Check specific build logs
cat _build/ios/build.log
cat _build/android/build.log
```

### Clean Build

```bash
# Clean everything and rebuild
mix clean
mix dala.release
```

### Check OTP Validity

```bash
# Validate OTP installation
mix dala.doctor

# Check OTP details
mix dala.cache show
```

## Next Steps

- See [Development Workflow Guide](development_workflow.md) for day-to-day development
- See [Beginner Step-by-Step Guide](beginner_guide.md) for getting started
- Read `build_release.md` for manual OTP cross-compilation details
