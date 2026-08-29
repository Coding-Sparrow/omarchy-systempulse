# System Pulse — an iStat-style system monitor for Omarchy

An iStat Menus-style system monitor for the [Omarchy](https://omarchy.org/) bar. Live CPU, memory, disk, network, battery, and temperature readings in the status bar, with a detail popup — all sampled directly from `/proc` and `/sys` with zero background processes.

![Bar](assets/bar.png)
![Detail panel](assets/panel.png)

## Features

- **Bar label** — compact, iStat-style: `CPU 6%   MEM 30%   ↓22k ↑1k   BAT 90%` (each segment toggleable)
- **Detail popup** (click the bar label):
  - **CPU** — usage hero, load averages, frequency, package temperature, per-core mini-bars, uptime
  - **History** — live sparklines for CPU, memory, network and battery (~4 minutes of samples)
  - **Memory** — used/total, cached, swap
  - **Disk** — root usage, live read/write speeds, NVMe temperature
  - **Network** — default interface, ↓/↑ speeds, totals since boot, local IP
  - **Battery** — charge, state, power draw, health vs design capacity, cycle count, time remaining
  - **Bar display** — toggle bar segments and alert notifications right in the popup
- **Alerts** — the bar label turns urgent when the battery runs low, the CPU runs hot, or the disk fills up; optional desktop notifications fire once per alert as it triggers
- **Right-click** — opens `btop` in a floating terminal for the deep dive
- **Vertical bar aware**, theme-aware (follows your Omarchy theme colors)
- Hover tooltip with an exact summary

Everything updates every 2 seconds via kernel interfaces (`/proc/stat`, `/proc/meminfo`, `/proc/diskstats`, `/proc/net/dev`, `/sys/class/power_supply`, `/sys/class/hwmon`). No subprocesses, no polling daemons, negligible CPU cost.

## Requirements

- Omarchy (with the Omarchy shell / Quickshell bar)
- `btop` (optional — only for the right-click detail view)

Battery, temperature, and network sections appear automatically when the hardware exposes them. Fans are shown only if the kernel exposes a fan sensor.

## Install

```bash
omarchy plugin add https://github.com/Coding-Sparrow/omarchy-systempulse.git --enable
```

## Remove

```bash
omarchy plugin disable coding-sparrow.systempulse   # hide it from the bar
omarchy plugin remove coding-sparrow.systempulse    # delete it entirely
```

## Settings

Easiest first: **click the bar widget** and use the toggles in the popup's "Bar display" section — they persist automatically.

You can also use the Omarchy CLI (no JSON editing needed):

```bash
omarchy bar set coding-sparrow.systempulse showNet false
omarchy bar set coding-sparrow.systempulse alertTemp 80
omarchy bar set coding-sparrow.systempulse notifications true
omarchy bar set coding-sparrow.systempulse interval 1000
```

Full list of keys (all optional — defaults shown):

| Key | Default | Purpose |
|-----|---------|---------|
| `showCpu` | `true` | CPU segment in the bar label and history |
| `showMem` | `true` | Memory segment and history |
| `showNet` | `true` | Network segment and history |
| `showBattery` | `true` | Battery segment and history (auto-hides without a battery) |
| `interval` | `2000` | Sample interval in milliseconds (500–10000) |
| `alertBattery` | `20` | Turn the label urgent when the battery (discharging) falls below this % |
| `alertTemp` | `85` | Turn the label urgent when the CPU package exceeds this °C |
| `alertDisk` | `90` | Turn the label urgent when the root disk exceeds this % |
| `notifications` | `false` | Fire a desktop notification once as each alert triggers |
| `detailCommand` | `btop` floating terminal | Command run on right-click |

Every key can also be set in the widget's entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "coding-sparrow.systempulse", "showNet": false, "notifications": true }
```

## How it works

The widget is a standard Omarchy shell plugin (Quickshell/QML):

- `SysMon.qml` — bar widget + sampler. Parses `/proc` and `/sys` files on a timer, computing deltas for CPU, disk I/O, and network speeds.
- `Panel.qml` — detail popup built on the shell's own `Panel`/`KeyboardPanel` infrastructure, bound live to the sampler.
- Device discovery (CPU/NVMe temperature paths, battery path) happens once at startup via `/sys/class/hwmon` and `/sys/class/power_supply`.

No config files are read or written outside the plugin's own settings in `shell.json`.

## License

[MIT](LICENSE)
