# Changelog

## 1.3.0

- Glance defaults: compact CPU sparkline + CPU% + memory% only. Disk, network, and battery are off on the bar so they do not duplicate stock Omarchy icons.
- Readable filled CPU sparkline on the bar.
- Bar disk % is the root filesystem (`/`), not a tiny `/boot` volume. Alerts still watch every mount.
- Popup leads with CPU, memory, and top processes. Click a process to open `btop`. History and extra stats follow. **Bar display** is collapsed until you open it.

## 1.2.0

- Bar: CPU mini-sparkline and a `DISK` segment; click a segment to open that block in the popup (accent highlight).
- Extra disks: unique filesystems (e.g. `/` and `/boot`), not only root; disk alerts name the mount.
- History sparklines labeled `… ago` → `now`; popup scrolls to the focused section when content is taller than the screen.
- Sampler/parsers live in `Model.js`. Run `node test/model-test.js`.

## 1.1.0

- Bar labels are real text items (Omarchy shell 4.x `WidgetButton` is PlainText; HTML labels no longer work).
- Alert toasts use `--app-name System Pulse`, open the panel on click, and dismiss when you click the widget — so a CPU-hot card cannot sit on top of the bar forever.
- CPU temperature discovery covers Intel `coretemp`, AMD `k10temp`/`zenpower`, ARM `cpu`/`soc_thermal`, and `acpitz` as a last resort.
- Battery parser accepts `CHARGE_*` packs as well as `ENERGY_*` (health, watts, time remaining).
- Default route is IPv4 first, then IPv6, so IPv6-only setups still get a network segment.
- Frequency falls back to `cpufreq/scaling_cur_freq` when `/proc/cpuinfo` has no MHz (ARM).
- GPU busy percent is shown when sysfs exposes `gpu_busy_percent`.
- Vertical bar shows every segment (not just CPU/MEM) and colors alerts.
- Per-core bars scale to the actual core count instead of assuming 22.
- Compact bar mode drops CPU/MEM/BAT prefixes.
- Memory alert (default 95%).
- Connectivity ping is **off by default**; enable “Ping check” in the panel if you want packet-loss alerts.
- Detail panel lists the top 5 processes by CPU while it is open.
- Manifest aliases, setting descriptions, version 1.1.0.
