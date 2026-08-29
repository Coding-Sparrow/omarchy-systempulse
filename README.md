# System Pulse — an iStat-style system monitor for Omarchy

An iStat Menus-style system monitor for the [Omarchy](https://omarchy.org/) bar. Live CPU, memory, disk, network, battery, and temperature readings in the status bar, with a detail popup — all sampled directly from `/proc` and `/sys` with zero background processes.

![Bar](assets/bar.png)
![Detail panel](assets/panel.png)

## Features

- **Bar label** — compact, iStat-style: `CPU 6%   MEM 30%   ↓22k ↑1k   BAT 90%` (each segment toggleable)
- **Detail popup** (click the bar label):
  - **CPU** — usage hero, load averages, frequency, package temperature, per-core mini-bars, uptime
  - **Memory** — used/total, cached, swap
  - **Disk** — root usage, live read/write speeds, NVMe temperature
  - **Network** — default interface, ↓/↑ speeds, totals since boot, local IP
  - **Battery** — charge, state, power draw, health vs design capacity, cycle count, time remaining
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

Edit the widget's entry in `~/.config/omarchy/shell.json` (hot-reloads on save):

```json
{
  "id": "coding-sparrow.systempulse",
  "showCpu": true,
  "showMem": true,
  "showNet": true,
  "showBattery": true,
  "interval": 2000,
  "detailCommand": "omarchy-launch-floating-terminal-with-presentation btop"
}
```

| Key | Default | Purpose |
|-----|---------|---------|
| `showCpu` | `true` | CPU segment in the bar label |
| `showMem` | `true` | Memory segment |
| `showNet` | `true` | Network ↓/↑ segment |
| `showBattery` | `true` | Battery segment (only shows when a battery exists) |
| `interval` | `2000` | Sample interval in milliseconds |
| `detailCommand` | `btop` floating terminal | Command run on right-click |

## How it works

The widget is a standard Omarchy shell plugin (Quickshell/QML):

- `SysMon.qml` — bar widget + sampler. Parses `/proc` and `/sys` files on a timer, computing deltas for CPU, disk I/O, and network speeds.
- `Panel.qml` — detail popup built on the shell's own `Panel`/`KeyboardPanel` infrastructure, bound live to the sampler.
- Device discovery (CPU/NVMe temperature paths, battery path) happens once at startup via `/sys/class/hwmon` and `/sys/class/power_supply`.

No config files are read or written outside the plugin's own settings in `shell.json`.

## License

[MIT](LICENSE)
