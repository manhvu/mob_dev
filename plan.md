# mob_dev — Roadmap

## MVP (ship these first)

- [x] Device discovery — Android (adb) + iOS simulator (xcrun simctl)
- [x] Per-device deploy buttons — "Update" and "First Deploy"
- [x] Live log streaming — adb logcat + xcrun simctl log stream
- [x] Log filter — App / All / per-device
- [x] Log text filter — free-text, comma-separated terms
- [x] Deploy output terminal — inline per device card
- [x] Elixir Logger → dashboard (Mob.AndroidLogger handler, mob_nif:log/2)
- [x] Dashboard QR code — LAN URL for opening dashboard on phone

## Nice to have

### Multi-device
- Multiple Android devices simultaneously
  - Requires: `MainActivity.java` reads `mob_dist_port` intent extra (already sent by mob_dev)
  - Requires: dynamic node name per device (e.g. `mob_demo_android_2@127.0.0.1`)
- Multiple iOS simulators simultaneously
  - Requires: `mob_beam.m` reads node name from `SIMCTL_CHILD_MOB_NODE_SUFFIX` env var
  - Port assignment already works (mob_dev assigns by index)
- Physical iOS devices
  - Requires: `iproxy` USB tunnel setup (libimobiledevice)
  - Discovery stub (`list_physical/0`) already exists in `MobDev.Discovery.IOS`

### Wireless device onboarding
- Android: QR code → `adb connect MAC_IP:5555` (wireless debugging)
  - Android 11+: use `adb pair` for one-time pairing
- iOS physical: QR code → iproxy tunnel setup
- Note: different QR content per platform for this flow

### Developer experience
- `mix mob.watch` — auto-deploy on file save (already planned in mob_dev)
- Hot-reload without restart — `nl(Module)` already works via IEx; add button in dashboard
- Node inspector — show running processes, memory, message queues via RPC

### Dashboard polish
- Dark/light theme toggle
- Persistent log filter preference (localStorage)
- Timestamps toggle (show/hide)
- Log level color legend
