# mob_dev

Development tooling for [Mob](https://github.com/genericjam/mob) — the BEAM-on-device mobile framework for Elixir.

## Installation

Add to your project's `mix.exs`:

```elixir
def deps do
  [
    {:mob_dev, "~> 0.2", only: :dev}
  ]
end
```

## Mix tasks

| Task | Description |
|------|-------------|
| `mix mob.deploy` | Compile + push BEAMs to all connected devices |
| `mix mob.deploy --native` | Also build and install the native APK/app |
| `mix mob.connect` | Tunnel + restart + open IEx connected to device nodes |
| `mix mob.watch` | Auto-push BEAMs on file save |
| `mix mob.devices` | List connected devices and their status |
| `mix mob.install` | First-run setup: download OTP, generate icons, write mob.exs |
| `mix mob.icon` | Regenerate app icons |
| `mix mob.battery_bench` | Battery benchmark — measure BEAM power draw on a real device |

---

## mix mob.battery_bench

Builds a benchmark APK with specific BEAM tuning flags, deploys it to an Android device,
and measures battery drain over time using the hardware charge counter (`dumpsys battery`).

Reports mAh every 10 seconds and prints a summary at the end.

**WiFi ADB is required** — a USB cable charges the device and skews measurements.

### WiFi ADB setup (one-time, while plugged in)

```bash
adb -s SERIAL tcpip 5555
adb connect PHONE_IP:5555
# unplug USB, then use PHONE_IP:5555 as --device
```

### Usage

```bash
# Default: Nerves-tuned BEAM, auto-detect device, 30 min
mix mob.battery_bench

# Baseline — build without starting the BEAM at all
mix mob.battery_bench --no-beam

# Named presets
mix mob.battery_bench --preset untuned   # raw BEAM, no tuning
mix mob.battery_bench --preset sbwt      # busy-wait disabled only
mix mob.battery_bench --preset nerves    # full Nerves set (same as default)

# Arbitrary BEAM VM flags
mix mob.battery_bench --flags "-sbwt none -S 1:1"

# Longer run (better mAh resolution)
mix mob.battery_bench --duration 3600

# Specify device
mix mob.battery_bench --device 192.168.1.42:5555

# Re-run without rebuilding the APK
mix mob.battery_bench --no-build
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--duration N` | 1800 | Benchmark duration in seconds |
| `--device SERIAL` | auto | adb device serial or `IP:port` |
| `--no-beam` | false | Baseline: build without starting the BEAM |
| `--preset NAME` | — | Named flag preset: `untuned`, `sbwt`, or `nerves` |
| `--flags "..."` | — | Arbitrary BEAM VM flags (space-separated) |
| `--no-build` | false | Skip APK build and install; benchmark current install |

`--no-beam`, `--preset`, and `--flags` are mutually exclusive. Use one at a time.

### What the presets do

| Preset | Flags | Notes |
|--------|-------|-------|
| `untuned` | *(none)* | Raw BEAM defaults — highest idle power use |
| `sbwt` | `-sbwt none -sbwtdcpu none -sbwtdio none` | Disable busy-wait only |
| `nerves` | `-S 1:1 -SDcpu 1:1 -SDio 1 -A 1 -sbwt none -sbwtdcpu none -sbwtdio none +C multi_time_warp` | Full Nerves-style set |
| *(default)* | same as `nerves` | Production default in mob |

### What the flags do

| Flag | Effect |
|------|--------|
| `-S 1:1 -SDcpu 1:1 -SDio 1` | Single scheduler — no idle CPU wakeups from scheduler migration |
| `-A 1` | Single async thread pool thread |
| `-sbwt none` etc. | Disable busy-waiting in all schedulers — CPU idles instead of spinning |
| `+C multi_time_warp` | Allow the system clock to jump forward; avoids spurious timer wakeups |

### Example output

```
=== Mob Battery Benchmark ===

  Device:   192.168.1.42:5555
  Package:  com.mob.demo
  Duration: 1800s (30 min)
  Mode:     default (Nerves tuning)

=== Building APK ===
  Running Gradle assembleDebug...
=== Installing APK ===
=== Pushing BEAMs ===

Battery level: 94%

==========================================
  Unplug the USB cable now if connected.
  Press Enter when ready to start the run.
==========================================

=== Resetting battery stats ===
Start charge: 4721 mAh

=== Launching app ===
=== Turning screen off ===
  Screen off.

Running for 30 min — do not touch the phone...

  [14:03:10]  0.2/30 min — 4721 mAh  (−0 mAh)
  [14:03:20]  0.3/30 min — 4720 mAh  (−1 mAh @ 180.0 mAh/hr)
  [14:13:10] 10.1/30 min — 4688 mAh  (−33 mAh @ 196.2 mAh/hr)
  [14:23:10] 20.1/30 min — 4654 mAh  (−67 mAh @ 200.1 mAh/hr)
  [14:33:10] 30.1/30 min — 4621 mAh  (−100 mAh @ 199.8 mAh/hr)

=== Summary: default (Nerves tuning) ===

  Duration:     30 min 6 sec
  Start:        4721 mAh  (94%)
  End:          4621 mAh  (92%)
  Drain:        100 mAh
  Rate:         199.6 mAh/hr

Lower mAh/hr = better. No-BEAM baseline is ~200 mAh/hr on Moto G.
```

### Understanding the results

Reference measurements on a Moto G phone (30-min screen-off runs):

| Config | mAh/hr | vs baseline |
|--------|--------|-------------|
| No BEAM (baseline) | ~200 | — |
| Nerves tuning (default) | ~202 | +1% |
| Untuned BEAM | ~250 | +25% |

The Nerves-tuned BEAM has essentially the same idle power draw as a stock Android app.
The overhead is in the noise for most workloads. The untuned BEAM costs ~25% more because
the schedulers busy-wait (spin) instead of sleeping when idle.

**Note on resolution:** The hardware charge counter typically has 1 mAh resolution.
At ~200 mAh/hr that means one tick every ~18 seconds. A 30-minute run gives you
~100 ticks — enough to distinguish configs that differ by more than a few percent.
For smaller differences, run longer (60–90 min).

### How it works under the hood

The BEAM flags are selected at compile time via preprocessor defines:

- For named presets (`--preset`), a simple `-DBEAM_UNTUNED` etc. flag is passed through
  Gradle to CMake to clang. These are identifier-only flags — no quoting issues.
- For arbitrary `--flags`, a C header file (`mob_beam_flags.h`) is generated in a temp
  directory and passed via `-I` + `-DBEAM_USE_CUSTOM_FLAGS`. The string literals live in
  generated C source, bypassing the shell → Gradle → CMake quoting pipeline entirely.
- `--no-beam` passes `-DNO_BEAM`, which makes `mob_start_beam()` return immediately.

The flag priority in `mob_beam.c`:
```
BEAM_USE_CUSTOM_FLAGS (generated header) > BEAM_UNTUNED / BEAM_SBWT_ONLY / BEAM_FULL_NERVES > default
```

### iOS

Physical iOS devices have a battery; the iOS simulator does not. iOS battery benchmarking
is not yet supported by this task. For physical iOS devices, use Xcode Instruments →
Energy Log while the app runs.
