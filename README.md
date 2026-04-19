# mob_dev

Development tooling for [Mob](https://hexdocs.pm/mob) — the BEAM-on-device mobile framework for Elixir.

[![Hex.pm](https://img.shields.io/hexpm/v/mob_dev.svg)](https://hex.pm/packages/mob_dev)

## Installation

Add to your project's `mix.exs` (dev only):

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
| `mix mob.new APP_NAME` | Generate a new Mob project (see `mob_new` archive) |
| `mix mob.install` | First-run setup: download OTP runtime, generate icons, write `mob.exs` |
| `mix mob.deploy` | Compile and push BEAMs to all connected devices |
| `mix mob.deploy --native` | Also build and install the native APK/iOS app |
| `mix mob.connect` | Tunnel + restart + open IEx connected to device nodes (`--name` for multiple sessions) |
| `mix mob.watch` | Auto-push BEAMs on file save |
| `mix mob.watch_stop` | Stop a running `mix mob.watch` |
| `mix mob.devices` | List connected devices and their status |
| `mix mob.push` | Hot-push only changed modules (no restart) |
| `mix mob.server` | Start the dev dashboard at `localhost:4040` |
| `mix mob.icon` | Regenerate app icons |
| `mix mob.routes` | Validate navigation destinations across the codebase |
| `mix mob.battery_bench_android` | Measure BEAM idle power draw on an Android device |
| `mix mob.battery_bench_ios` | Measure BEAM idle power draw on a physical iOS device |

## Dev dashboard (`mix mob.server`)

`mix mob.server` starts a local Phoenix server (default port 4040) with:

- **Device cards** — live status for connected Android emulators and iOS simulators, with Deploy and Update buttons per device
- **Device log panel** — streaming logcat / iOS simulator console with text filter
- **Elixir log panel** — Elixir `Logger` output forwarded from the running BEAM, with text filter
- **Watch mode toggle** — auto-push changed BEAMs on file save without running a separate terminal
- **QR code** — LAN URL for opening the dashboard on a physical device

Run with IEx for an interactive terminal alongside the dashboard:

```bash
iex -S mix mob.server
```

### Watch mode

Click **Watch** in the dashboard header or control it programmatically:

```elixir
MobDev.Server.WatchWorker.start_watching()
MobDev.Server.WatchWorker.stop_watching()
MobDev.Server.WatchWorker.status()
#=> %{active: true, nodes: [:"my_app_ios@127.0.0.1"], last_push: ~U[...]}
```

Watch events broadcast on `"watch"` PubSub topic:

```elixir
{:watch_status, :watching | :idle}
{:watch_push,   %{pushed: [...], failed: [...], nodes: [...], files: [...]}}
```

## Hot-push transport (`mix mob.deploy`)

When Erlang distribution is reachable, `mix mob.deploy` hot-pushes changed BEAMs in-place via RPC — no `adb push`, no app restart. The running modules are replaced exactly like `nl/1` in IEx.

```
Pushing 14 BEAM file(s) to 2 device(s)...
  Pixel_7_API_34  →  pushing... ✓ (dist, no restart)
  iPhone 15 Pro   →  pushing... ✓ (dist, no restart)
```

If dist is not reachable (first deploy, app not running), it falls back to `adb push` + restart. Mixed deploys work — one device can hot-push while another restarts.

**Requirements:** The app must call `Mob.Dist.ensure_started/1` at startup, and the cookie must match the one in `mob.exs` (default `:mob_secret`).

## Navigation validation (`mix mob.routes`)

Validates all `push_screen`, `reset_to`, and `pop_to` destinations across `lib/**/*.ex` via AST analysis. Module destinations are verified with `Code.ensure_loaded/1`.

```bash
mix mob.routes           # print warnings
mix mob.routes --strict  # exit non-zero (for CI)
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

### Android (`mix mob.battery_bench_android`)

Deploys an APK and measures drain via the hardware charge counter (`dumpsys battery`). Reports mAh every 10 seconds.

**WiFi ADB required** — a USB cable charges the device and skews measurements.

```bash
# One-time WiFi ADB setup (while plugged in):
adb -s SERIAL tcpip 5555
adb connect PHONE_IP:5555
# then unplug

mix mob.battery_bench_android                              # default: Nerves-tuned BEAM, 30 min
mix mob.battery_bench_android --no-beam                    # baseline: no BEAM at all
mix mob.battery_bench_android --preset untuned             # raw BEAM, no tuning
mix mob.battery_bench_android --flags "-sbwt none -S 1:1"
mix mob.battery_bench_android --duration 3600 --device 192.168.1.42:5555
mix mob.battery_bench_android --no-build                   # re-run without rebuilding
```

### iOS (`mix mob.battery_bench_ios`)

Deploys to a physical iPhone/iPad and reads battery via `ideviceinfo`. Reports mAh (if `BatteryMaxCapacity` is available) or percentage points.

**Prerequisites:** `brew install libimobiledevice`, Xcode 15+, device trusted on this Mac.

```bash
mix mob.battery_bench_ios                                  # default: Nerves-tuned BEAM, 30 min
mix mob.battery_bench_ios --no-beam                        # baseline: no BEAM at all
mix mob.battery_bench_ios --preset untuned                 # raw BEAM, no tuning
mix mob.battery_bench_ios --flags "-sbwt none -S 1:1"
mix mob.battery_bench_ios --duration 3600 --device UDID
mix mob.battery_bench_ios --no-build                       # re-run without rebuilding
```

### Presets and results

| Preset | Flags | mAh/hr (Moto G) |
|--------|-------|----------------|
| No BEAM | — | ~200 |
| Nerves (default) | `-S 1:1 -SDcpu 1:1 -SDio 1 -A 1 -sbwt none` | ~202 |
| Untuned | *(none)* | ~250 |

The Nerves-tuned BEAM is essentially indistinguishable from a stock Android app at idle. The untuned BEAM costs ~25% more because schedulers spin-wait instead of sleeping.

## Working with an agent (Claude Code / LLM)

Because OTP runs on the device, an agent can connect directly to the running app via Erlang distribution and inspect or drive it programmatically — no screenshots required.

### How it works

```
Agent (Claude Code)
    │
    ├── mix mob.connect      → tunnels EPMD, connects IEx to device node
    │
    ├── Mob.Test.*           → inspect screen state, trigger taps via RPC
    │   (exact state: module, assigns, render tree)
    │
    └── MCP tools            → native UI when needed
        ├── adb-mcp          → Android: screenshot, shell, UI inspect
        └── ios-simulator-mcp → iOS: screenshot, tap, describe UI
```

### Mob.Test — preferred for agents

`Mob.Test` gives exact app state via Erlang distribution. Prefer it over screenshots whenever possible — it doesn't depend on rendering, is instantaneous, and works offline.

```elixir
node = :"my_app_ios@127.0.0.1"

# Inspection
Mob.Test.screen(node)               #=> MyApp.HomeScreen
Mob.Test.assigns(node)              #=> %{count: 3, user: %{name: "Alice"}, ...}
Mob.Test.find(node, "Save")         #=> [{[0, 2], %{"type" => "button", ...}}]
Mob.Test.inspect(node)              # full snapshot: screen + assigns + nav history + tree

# Tap a button by tag atom (from on_tap: {self(), :save} in render/1)
Mob.Test.tap(node, :save)

# Navigation — synchronous, safe to read state immediately after
Mob.Test.back(node)                 # system back gesture (fire-and-forget)
Mob.Test.pop(node)                  # pop to previous screen (synchronous)
Mob.Test.navigate(node, MyApp.DetailScreen, %{id: 42})
Mob.Test.pop_to(node, MyApp.HomeScreen)
Mob.Test.pop_to_root(node)
Mob.Test.reset_to(node, MyApp.HomeScreen)

# List interaction
Mob.Test.select(node, :my_list, 0)  # select first row

# Simulate device API results (permission dialogs, camera, location, etc.)
Mob.Test.send_message(node, {:permission, :camera, :granted})
Mob.Test.send_message(node, {:camera, :photo, %{path: "/tmp/p.jpg", width: 1920, height: 1080}})
Mob.Test.send_message(node, {:location, %{lat: 43.65, lon: -79.38, accuracy: 10.0, altitude: 80.0}})
Mob.Test.send_message(node, {:notification, %{id: "n1", title: "Hi", body: "Hey", data: %{}, source: :push}})
Mob.Test.send_message(node, {:biometric, :success})
```

### Accessing IEx alongside an agent

**Option 1 — shared session (`iex -S mix mob.server`):**

```bash
iex -S mix mob.server
```

Starts the dev dashboard and gives you an IEx prompt in the same process. The agent uses Tidewave to execute `Mob.Test.*` calls in this session; you type directly in the same IEx prompt. Both share the same connected node and see the same live state. This is the recommended setup for working alongside an agent.

**Option 2 — separate sessions (`--name`):**

Because Erlang distribution allows multiple nodes to connect to the same device, you can run independent sessions simultaneously:

```bash
# Your terminal
mix mob.connect --name mob_dev_1@127.0.0.1

# Agent's terminal (or a second developer)
mix mob.connect --name mob_dev_2@127.0.0.1
```

Both connect to the same device nodes, can call `Mob.Test.*` and `nl/1`, and don't interfere with each other.

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

### Recommended CLAUDE.md for Mob projects

Add a `CLAUDE.md` to your Mob project root to give an agent the context it needs:

````markdown
# MyApp — Agent Instructions

## Connecting to a running device

```bash
mix mob.connect          # discover, tunnel, connect IEx
mix mob.connect --no-iex # print node names without IEx
mix mob.devices          # list connected devices
```

Node names:
- iOS simulator:    `my_app_ios@127.0.0.1`
- Android emulator: `my_app_android@127.0.0.1`

## Inspecting and driving the running app

Prefer `Mob.Test` over screenshots — it gives exact state, not a visual approximation.

```elixir
node = :"my_app_ios@127.0.0.1"

# Inspection
Mob.Test.screen(node)       # current screen module
Mob.Test.assigns(node)      # current assigns map
Mob.Test.find(node, "text") # find UI nodes by visible text
Mob.Test.inspect(node)      # full snapshot: screen + assigns + nav history + tree

# Interaction
Mob.Test.tap(node, :tag)              # tap by tag atom (from on_tap: {self(), :tag} in render/1)
Mob.Test.back(node)                   # system back gesture
Mob.Test.pop(node)                    # pop to previous screen (synchronous)
Mob.Test.navigate(node, Screen, %{})  # push a screen (synchronous)
Mob.Test.select(node, :list_id, 0)    # select a list row

# Simulate device API results
Mob.Test.send_message(node, {:permission, :camera, :granted})
Mob.Test.send_message(node, {:camera, :photo, %{path: "/tmp/p.jpg", width: 1920, height: 1080}})
Mob.Test.send_message(node, {:biometric, :success})
```

Navigation functions (`pop`, `navigate`, `pop_to`, `pop_to_root`, `reset_to`) are
synchronous — safe to read state immediately after.

`back/1` and `send_message/2` are fire-and-forget. If you need to wait:

```elixir
Mob.Test.back(node)
:rpc.call(node, :sys, :get_state, [:mob_screen])  # flush
Mob.Test.screen(node)
```

## Hot-pushing code changes

```bash
mix mob.push          # compile + push all changed modules to all connected devices
mix mob.push --all    # force-push every module
```

## Deploying

```bash
mix mob.deploy          # push changed BEAMs, restart
mix mob.deploy --native # full native rebuild + install
```
````

### Agent workflow example

A typical agent session for debugging or feature work:

```
1. mix mob.connect                        — connect to the running device node
2. Mob.Test.screen(node)                  — confirm which screen is showing
3. Mob.Test.assigns(node)                 — inspect current state
4. Mob.Test.tap(node, :some_button)       — interact with the UI
5. Mob.Test.screen(node)                  — confirm navigation happened
6. edit lib/my_app/screen.ex              — make a code change
7. mix mob.push                           — hot-push changed modules without restart
8. Mob.Test.assigns(node)                 — verify state updated as expected
```

For device API interactions, simulate the result rather than triggering real hardware:

```elixir
# Instead of actually opening the camera:
Mob.Test.tap(node, :take_photo)     # triggers handle_event → Mob.Camera.capture_photo
# Simulate the result:
Mob.Test.send_message(node, {:camera, :photo, %{path: "/tmp/test.jpg", width: 1920, height: 1080}})
Mob.Test.assigns(node)              # verify photo_path was stored
```

If you need to see the rendered UI, take a screenshot with the native MCP tool, then use `Mob.Test.find/2` to correlate what you see with the component tree.
