# System Pulse

An [iStat Menus](https://bjango.com/mac/istatmenus/)-style system monitor for the [Omarchy](https://omarchy.org/) bar.

Live CPU, memory, disk, network, battery, GPU, and temperature in the status bar, plus a detail popup. Samples `/proc` and `/sys` every 2 seconds. No extra daemons. Ping is off unless you turn it on.

Plugin ID: `coding-sparrow.systempulse` · Version **1.2.0** · [MIT](LICENSE)

**On the bar** — CPU, memory, disk, network, and battery, next to the rest of the Omarchy tray:

![System Pulse on the Omarchy bar](assets/bar.png)

**Click the widget** (or a single segment) for the detail popup — cores, extra disks, processes, history, and toggles:

![System Pulse detail popup](assets/panel.png)

Marketplace: [omarchyplugins.com](https://omarchyplugins.com) (search **System Pulse**).

---

## What you see on the bar

A typical label:

```
▁▂▃  CPU 6%   MEM 30%   DISK 9%   ↓22k ↑1k   BAT 90%
```

| Piece | Meaning |
|--------|---------|
| Mini sparkline | CPU over the last samples |
| `CPU` | Total CPU busy % |
| `MEM` | Used memory % (`MemTotal − MemAvailable`) |
| `DISK` | Fullest real filesystem % |
| `↓ ↑` | Download / upload on the default route |
| `BAT` | Charge % (laptops; hidden on desktops) |
| `GPU` | Busy % only if the kernel exposes `gpu_busy_percent` |

Segments you don't want can be toggled off. **Compact bar** drops the words: `6%  30%  9%  ↓22k ↑1k  90%`.

Failing resources turn **urgent** (theme urgent color) — only that segment, not the whole widget.

Hover the widget for a one-line tooltip (CPU, memory GB, network, battery state, package temp).

---

## How to use it

| Action | What happens |
|--------|----------------|
| **Left-click the widget** | Open / close the detail popup |
| **Left-click a segment** (`CPU`, `MEM`, `DISK`, `NET`, `BAT`) | Open the popup, highlight that block, scroll to it if the panel is tall |
| **Right-click** | Open `btop` in a floating terminal (optional; needs `btop`) |
| **Click an alert toast** | Opens the popup (toasts are named “System Pulse” and won't sit on top of the widget forever) |

Inside the popup:

1. **CPU** — big %, load averages, frequency, package °C, GPU % if present, per-core bars (any core count), uptime
2. **Memory** — used / total, cached, swap
3. **Disk** — each real filesystem (e.g. `/` and `/boot`; bind mounts of the same device are merged), read/write speed, NVMe °C
4. **Network** — default iface (IPv4, else IPv6), live ↓/↑, totals since boot, local IP
5. **Battery** — %, status, watts, health vs design, cycles, time remaining
6. **Processes** — top 5 by CPU, sampled only while the popup is open
7. **History** — sparklines for CPU, memory, network, battery, with `… ago` → `now` (fills up to ~4 minutes at the default interval)
8. **Bar display** — toggles that persist to `shell.json`

Vertical bars stack the same segments and still color alerts.

---

## Install

```bash
omarchy plugin add https://github.com/Coding-Sparrow/omarchy-systempulse.git --enable
```

Place it on the bar if the installer didn't:

```bash
omarchy plugin enable coding-sparrow.systempulse --section right
```

### Update

```bash
omarchy plugin update coding-sparrow.systempulse
```

### Hide or remove

```bash
omarchy plugin disable coding-sparrow.systempulse   # leave files, hide from the bar
omarchy plugin remove coding-sparrow.systempulse    # delete the checkout
```

### Requirements

- Omarchy with the Omarchy shell / Quickshell bar (4.x)
- `btop` — optional, only for right-click

No other packages. GPU, battery, NVMe temp, and fans-of-sensors appear only when the kernel exposes them.

---

## Configure

**Easiest:** click the widget → **Bar display** at the bottom. Toggles save themselves.

Or CLI (no JSON editing):

```bash
omarchy bar set coding-sparrow.systempulse compactBar true
omarchy bar set coding-sparrow.systempulse showNet false
omarchy bar set coding-sparrow.systempulse showDisk false
omarchy bar set coding-sparrow.systempulse notifications true
omarchy bar set coding-sparrow.systempulse alertTemp 80
omarchy bar set coding-sparrow.systempulse interval 1000
omarchy bar set coding-sparrow.systempulse checkConnectivity true
```

Or in `~/.config/omarchy/shell.json` on the widget entry:

```json
{
  "id": "coding-sparrow.systempulse",
  "compactBar": true,
  "showNet": false,
  "notifications": true
}
```

### Settings

All keys are optional.

| Key | Default | What it does |
|-----|---------|----------------|
| `showCpu` | `true` | CPU % + sparkline on the bar |
| `showMem` | `true` | Memory % |
| `showDisk` | `true` | Fullest filesystem % |
| `showNet` | `true` | ↓/↑ on the default route |
| `showBattery` | `true` | Battery % (auto-hides if there is no pack) |
| `showGpu` | `true` | GPU % when sysfs has `gpu_busy_percent` |
| `compactBar` | `false` | Drop `CPU` / `MEM` / `DISK` / `BAT` prefixes |
| `checkConnectivity` | `false` | Periodic ping for packet-loss alerts (off = no extra network) |
| `interval` | `2000` | Sample period in ms (500–10000) |
| `alertBattery` | `20` | Urgent while discharging at or below this % |
| `alertTemp` | `85` | Urgent when CPU package °C is at or above this |
| `alertMem` | `95` | Urgent when used memory % is at or above this |
| `alertDisk` | `90` | Urgent when any listed filesystem is this full |
| `notifications` | `false` | One desktop notification per alert as it starts; click opens the popup |
| `pingInterval` | `10000` | Ping period in ms (only if ping check is on) |
| `netAlertFailures` | `3` | Failed pings in a row before the network segment turns red |
| `detailCommand` | floating `btop` | Command run on right-click |

---

## Alerts

| Condition | Bar |
|-----------|-----|
| Battery discharging ≤ `alertBattery` | `BAT` urgent |
| CPU package ≥ `alertTemp` | `CPU` urgent |
| Memory ≥ `alertMem` | `MEM` urgent |
| Any disk ≥ `alertDisk` | `DISK` urgent; notification names the mount |
| Ping check on, and N failed probes | network segment urgent |

Notifications fire **once** when an alert starts, not every sample. Clicking the toast opens the panel and dismisses System Pulse toasts so they cannot cover the widget.

---

## Hardware notes

Works without extra setup on typical Omarchy laptops and desktops.

- **CPU temp:** Intel `coretemp` (Package id), AMD `k10temp` / `zenpower` (Tctl/Tdie), ARM `cpu` / `soc_thermal`, then `acpitz`
- **CPU frequency:** `/proc/cpuinfo` MHz, or `cpufreq/scaling_cur_freq` (ARM)
- **Battery:** `ENERGY_*` or `CHARGE_*` sysfs (health, watts, time left)
- **Network:** IPv4 default route first, IPv6 if that's all there is
- **GPU:** shown only if `/sys/class/drm/card*/device/gpu_busy_percent` exists (common on AMD; often missing on Intel)
- **Disks:** unique block devices, tmpfs/overlay skipped; `/` preferred over `/home` when they are the same volume

---

## How it works

Omarchy shell plugin (Quickshell / QML):

| File | Role |
|------|------|
| `SysMon.qml` | Bar widget, FileViews, timers, IPC |
| `Panel.qml` | Detail popup (`Panel` / `KeyboardPanel`) |
| `Sparklines.qml` | History graphs |
| `Model.js` | Parsing and formatting (`/proc`, `/sys`, `df`, `ps`) |

Reads kernel interfaces on a timer (`/proc/stat`, `/proc/meminfo`, `/proc/diskstats`, `/proc/net/dev`, `/proc/net/route`, `/proc/net/ipv6_route`, `/sys/class/power_supply`, `/sys/class/hwmon`). Discovery of temp/battery/GPU paths runs once at startup.

Does **not** write anything except its own keys in `shell.json`. Ping to `1.1.1.1` runs only if **Ping check** is on.

IPC (optional):

```bash
omarchy-shell coding-sparrow.systempulse open
omarchy-shell coding-sparrow.systempulse close
omarchy-shell coding-sparrow.systempulse toggle
omarchy-shell coding-sparrow.systempulse refresh
```

---

## Develop

After install, the checkout Omarchy already cloned is:

`~/.config/omarchy/plugins/coding-sparrow.systempulse/`

Edits there hot-reload. Validate and test from that directory:

```bash
omarchy plugin validate .
node test/model-test.js
```

If a change doesn't apply: `omarchy-shell shell rescanPlugins` or `omarchy restart shell`.

See [CHANGELOG.md](CHANGELOG.md) for 1.2.0 / 1.1.0 notes.

---

## License

[MIT](LICENSE) © Coding-Sparrow
