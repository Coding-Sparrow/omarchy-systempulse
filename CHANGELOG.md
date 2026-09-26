# Changelog

## 1.5.1

- Security: every `Text` renders as `Text.PlainText`, so process names from `/proc/<pid>/stat` and mount paths containing markup can't make Qt load an external resource when the panel opens. The mount path in the disk-full notification body is markup-escaped too.

## 1.5.0

- **Processes show current CPU**, not the lifetime average `ps pcpu` reported. Sampled from `/proc/*/stat` deltas (100% = one core, like `top`).
- **Intel GPU busy %** from i915 `rc6_residency_ms` / xe `idle_residency_ms`. Not read while the iGPU is runtime-suspended, so it never wakes the GPU.
- Disk I/O sums physical disks instead of only `dm-*` on LUKS/LVM systems, so other drives are included. USB drives plugged in after login are picked up, with no spike on the first sample.
- Network uses the lowest-metric default route and clears on disconnect instead of sticking to a stale interface.
- Alerts: hysteresis, a 3-sample requirement for CPU temperature, a 10-minute re-notify cooldown, and a queue so simultaneous alerts all get a toast.
- Disk-full alert ignores removable media and ISO/UDF/EROFS images. `df` runs under `timeout 5` so a stale NFS/SMB mount can't hang it.
- Battery: peripheral batteries (`scope=Device`) are no longer used as the system battery. Multiple packs are combined. Shows time to full while charging.
- GPU bar segment focuses the CPU/GPU block; long mount paths elide instead of overlapping the size.
- `interval` / `pingInterval` are clamped to sane ranges.

## 1.4.0

- Battery watts match the Omarchy power widget (sysfs µW → W). A 21.5 W charge no longer shows as `21513339.0 W`.
- Optional **VRAM** bar segment and a VRAM used/total bar in the popup. Reads AMD `mem_info_vram_*` sysfs, or `nvidia-smi` when that is all the machine has.

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
