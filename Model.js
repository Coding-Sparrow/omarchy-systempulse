// Pure parsing/format helpers for System Pulse.
// No Qt/QML types so this can be reasoned about (and later tested) as plain JS.

function clampPct(v) {
  return Math.max(0, Math.min(100, Math.round(v)))
}

// Escape text that ends up somewhere markup may be interpreted (e.g.
// notification bodies). Process names and mount paths are attacker-chosen.
function escapeMarkup(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")
}

function speed(bps) {
  if (bps < 1024) return Math.round(bps) + " B/s"
  if (bps < 1048576) return (bps / 1024).toFixed(bps < 10240 ? 1 : 0) + " kB/s"
  return (bps / 1048576).toFixed(1) + " MB/s"
}

function speedShort(bps) {
  if (bps < 1024) return "0k"
  if (bps < 1048576) return Math.round(bps / 1024) + "k"
  return (bps / 1048576).toFixed(1) + "M"
}

function pushHistory(arr, value, historyMax) {
  arr.push(value)
  if (arr.length > historyMax) arr.shift()
  return arr
}

function historyLabel(intervalMs, samples) {
  var n = samples || 0
  var sec = Math.max(0, n > 1 ? (n - 1) : 0) * (intervalMs || 0) / 1000
  if (sec < 15) return "filling…"
  if (sec < 90) return "last " + Math.round(sec) + "s"
  var min = Math.round(sec / 60)
  return "last ~" + min + " min"
}

function parseStat(content, prevCpu, prevCores) {
  var lines = String(content).split("\n")
  var totals = null
  var newCores = []
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line.indexOf("cpu") !== 0) continue
    var f = line.trim().split(/\s+/)
    if (f.length < 5) continue
    var idleAll = Number(f[4]) + Number(f[5])
    var t = 0
    for (var j = 1; j < f.length; j++) t += Number(f[j])
    var busy = t - idleAll
    if (f[0] === "cpu") totals = { busy: busy, total: t }
    else newCores.push({ busy: busy, total: t })
  }
  if (!totals) return null

  var cpuPercent = 0
  var hadPrev = false
  if (prevCpu) {
    var dT = totals.total - prevCpu.total
    var dB = totals.busy - prevCpu.busy
    if (dT > 0) {
      cpuPercent = clampPct(100 * dB / dT)
      hadPrev = true
    }
  }

  var per = []
  var prev = prevCores || []
  for (var k = 0; k < newCores.length; k++) {
    var p = prev[k]
    var pct = 0
    if (p) {
      var dt = newCores[k].total - p.total
      var db = newCores[k].busy - p.busy
      if (dt > 0) pct = Math.max(0, Math.min(100, 100 * db / dt))
    }
    per.push(pct)
  }

  return {
    cpuPercent: cpuPercent,
    hadPrev: hadPrev,
    prevCpu: totals,
    cores: per,
    prevCores: newCores
  }
}

function parseLoadavg(content) {
  var f = String(content).trim().split(/\s+/)
  if (f.length >= 3) return f[0] + " " + f[1] + " " + f[2]
  return ""
}

function parseUptime(content) {
  var f = String(content).trim().split(/\s+/)
  if (f.length >= 1) return Number(f[0])
  return 0
}

function parseCpuinfo(content) {
  var matches = String(content).match(/cpu MHz\s*:\s*([0-9.]+)/g)
  if (!matches || matches.length === 0) return { haveMhz: false, freqGhz: 0 }
  var sum = 0
  for (var i = 0; i < matches.length; i++) {
    sum += Number(matches[i].split(":")[1])
  }
  return { haveMhz: true, freqGhz: sum / matches.length / 1000 }
}

function parseScalingFreq(content) {
  var khz = Number(String(content).trim())
  if (!isNaN(khz) && khz > 0) return khz / 1000000
  return 0
}

function parseMeminfo(content) {
  var m = function(key) {
    var match = String(content).match(new RegExp(key + ":\\s+(\\d+)"))
    return match ? Number(match[1]) : 0
  }
  var totalKb = m("MemTotal")
  var availKb = m("MemAvailable")
  var swapTotalKb = m("SwapTotal")
  var swapFreeKb = m("SwapFree")
  return {
    cachedGb: m("Cached") / 1048576,
    memTotalGb: totalKb / 1048576,
    memUsedGb: (totalKb - availKb) / 1048576,
    memPercent: totalKb > 0 ? 100 * (totalKb - availKb) / totalKb : 0,
    swapTotalGb: swapTotalKb / 1048576,
    swapUsedGb: (swapTotalKb - swapFreeKb) / 1048576,
    swapPercent: swapTotalKb > 0 ? 100 * (swapTotalKb - swapFreeKb) / swapTotalKb : 0
  }
}

function skipDiskName(name) {
  return /^(loop|ram|zram|sr|fd)/.test(name)
}

function discoverDiskDevices(content) {
  var lines = String(content).trim().split("\n")
  var names = []
  var hasDm = false
  for (var i = 0; i < lines.length; i++) {
    var f = lines[i].trim().split(/\s+/)
    if (f.length < 10) continue
    if (/^dm-/.test(f[2])) { hasDm = true; break }
  }
  for (var j = 0; j < lines.length; j++) {
    var g = lines[j].trim().split(/\s+/)
    if (g.length < 10) continue
    var name = g[2]
    if (hasDm) {
      if (/^dm-/.test(name)) names.push(name)
    } else if (/^(nvme[0-9]+n[0-9]+|sd[a-z]|vd[a-z]|mmcblk[0-9]+)$/.test(name)) {
      names.push(name)
    }
  }
  return names
}

// Whole physical disks only. Counting physical devices (not dm-*/md*) sees every
// drive exactly once, whether it sits under LUKS/LVM/RAID or not, and still
// catches hot-plugged USB disks that were not there at startup.
function isPhysicalDisk(name) {
  return /^(nvme[0-9]+n[0-9]+|sd[a-z]+|vd[a-z]+|xvd[a-z]+|hd[a-z]+|mmcblk[0-9]+)$/.test(name)
}

// diskDevices is optional: pass an array to restrict to those names (legacy),
// or null/undefined to auto-select physical disks each sample.
function parseDiskstats(content, diskDevices, prevDisk, now) {
  var lines = String(content).trim().split("\n")
  var devs = {}
  var prevDevs = prevDisk && prevDisk.devs ? prevDisk.devs : null
  var dRead = 0
  var dWrite = 0
  var readSectors = 0
  var writeSectors = 0
  for (var k = 0; k < lines.length; k++) {
    var h = lines[k].trim().split(/\s+/)
    if (h.length < 10) continue
    var name = h[2]
    if (skipDiskName(name)) continue
    if (diskDevices && diskDevices.length) {
      if (diskDevices.indexOf(name) === -1) continue
    } else if (!isPhysicalDisk(name)) continue
    var r = Number(h[5])
    var w = Number(h[9])
    devs[name] = { read: r, write: w }
    readSectors += r
    writeSectors += w
    // Only diff devices seen last time, so a newly plugged disk's lifetime
    // counters do not show up as one giant spike.
    var p = prevDevs ? prevDevs[name] : null
    if (p) {
      dRead += Math.max(0, r - p.read)
      dWrite += Math.max(0, w - p.write)
    }
  }
  var readSpeed = 0
  var writeSpeed = 0
  if (prevDisk) {
    var dt = (now - prevDisk.time) / 1000
    if (dt > 0) {
      if (!prevDevs) {
        dRead = Math.max(0, readSectors - prevDisk.read)
        dWrite = Math.max(0, writeSectors - prevDisk.write)
      }
      readSpeed = dRead * 512 / dt
      writeSpeed = dWrite * 512 / dt
    }
  }
  return {
    readSpeed: readSpeed,
    writeSpeed: writeSpeed,
    prevDisk: { time: now, read: readSectors, write: writeSectors, devs: devs }
  }
}

function parseNetDev(content) {
  var lines = String(content).trim().split("\n")
  var stats = {}
  for (var i = 2; i < lines.length; i++) {
    var parts = lines[i].split(":")
    if (parts.length < 2) continue
    var name = parts[0].trim()
    if (name === "lo") continue
    var f = parts[1].trim().split(/\s+/)
    if (f.length < 10) continue
    stats[name] = { rx: Number(f[0]), tx: Number(f[8]) }
  }
  return stats
}

// Default route with the lowest metric wins (e.g. ethernet 100 over wifi 600).
// Point-to-point tunnels (wg/tun) have a 0.0.0.0 gateway, so accept those too
// as long as the route is up and the mask is /0.
function parseV4DefaultIface(content) {
  var lines = String(content).trim().split("\n")
  var best = ""
  var bestMetric = Infinity
  for (var i = 1; i < lines.length; i++) {
    var f = lines[i].trim().split(/\s+/)
    if (f.length < 8 || f[1] !== "00000000" || f[7] !== "00000000") continue
    var flags = parseInt(f[3], 16)
    if (!isNaN(flags) && (flags & 1) === 0) continue
    var metric = Number(f[6]) || 0
    if (metric < bestMetric) { best = f[0]; bestMetric = metric }
  }
  return best
}

function parseV6DefaultIface(content) {
  var lines = String(content).trim().split("\n")
  var best = ""
  var bestMetric = Infinity
  for (var i = 0; i < lines.length; i++) {
    var f = lines[i].trim().split(/\s+/)
    if (f.length < 10) continue
    if (f[0] !== "00000000000000000000000000000000" || f[1] !== "00" || f[9] === "lo") continue
    var flags = parseInt(f[8], 16)
    if (!isNaN(flags) && ((flags & 1) === 0 || (flags & 0x200) !== 0)) continue // !RTF_UP or RTF_REJECT
    var metric = parseInt(f[5], 16)
    if (isNaN(metric)) metric = 0
    if (metric < bestMetric) { best = f[9]; bestMetric = metric }
  }
  return best
}

function netRates(iface, stats, prevNet, now) {
  if (!iface) return null
  var s = stats[iface]
  if (!s) return null
  var down = 0
  var up = 0
  if (prevNet && prevNet.iface === iface) {
    var dt = (now - prevNet.time) / 1000
    if (dt > 0) {
      down = Math.max(0, (s.rx - prevNet.rx) / dt)
      up = Math.max(0, (s.tx - prevNet.tx) / dt)
    }
  }
  return {
    down: down,
    up: up,
    rxTotal: s.rx,
    txTotal: s.tx,
    prevNet: { time: now, iface: iface, rx: s.rx, tx: s.tx }
  }
}

function normalizeWatts(watts) {
  var w = Math.abs(Number(watts) || 0)
  // Sysfs POWER_NOW is microwatts. If that conversion is skipped, a 21.5 W
  // charge shows up as 21513339.0 W (GitHub issue #1). Battery packs do not
  // draw kilowatts, so keep scaling until the reading is plausible.
  while (w >= 2000) w /= 1000
  return w
}

function batteryPowerW(powerNow, voltageNow, currentNow) {
  var p = Number(powerNow) || 0
  var watts = 0
  if (p > 0)
    watts = p / 1000000
  else {
    var v = Number(voltageNow) || 0
    var c = Number(currentNow) || 0
    if (v !== 0 && c !== 0)
      watts = Math.abs(v * c) / 1000000000000
  }
  return normalizeWatts(watts)
}

function parseVramBytes(usedText, totalText) {
  var used = Number(String(usedText == null ? "" : usedText).trim())
  var total = Number(String(totalText == null ? "" : totalText).trim())
  if (!(total > 0) || isNaN(used) || used < 0) return null
  return {
    usedGb: used / 1073741824,
    totalGb: total / 1073741824,
    percent: 100 * used / total
  }
}

function parseVramSmi(content) {
  var lines = String(content).trim().split("\n")
  var usedMiB = 0
  var totalMiB = 0
  var n = 0
  for (var i = 0; i < lines.length; i++) {
    var f = lines[i].split(",")
    if (f.length < 2) continue
    var u = Number(String(f[0]).replace(/[^0-9.]/g, ""))
    var t = Number(String(f[1]).replace(/[^0-9.]/g, ""))
    if (isNaN(u) || isNaN(t) || t <= 0) continue
    usedMiB += u
    totalMiB += t
    n++
  }
  if (n === 0) return null
  return {
    usedGb: usedMiB / 1024,
    totalGb: totalMiB / 1024,
    percent: 100 * usedMiB / totalMiB
  }
}

function parseBattery(content) {
  var map = {}
  var lines = String(content).trim().split("\n")
  for (var i = 0; i < lines.length; i++) {
    var kv = lines[i].split("=")
    if (kv.length === 2) map[kv[0]] = kv[1]
  }

  var cap = Number(map["POWER_SUPPLY_CAPACITY"])
  var energyNow = Number(map["POWER_SUPPLY_ENERGY_NOW"]) || 0
  var energyFull = Number(map["POWER_SUPPLY_ENERGY_FULL"]) || 0
  var energyDesign = Number(map["POWER_SUPPLY_ENERGY_FULL_DESIGN"]) || 0
  var chargeNow = Number(map["POWER_SUPPLY_CHARGE_NOW"]) || 0
  var chargeFull = Number(map["POWER_SUPPLY_CHARGE_FULL"]) || 0
  var chargeDesign = Number(map["POWER_SUPPLY_CHARGE_FULL_DESIGN"]) || 0

  if (isNaN(cap) && energyFull <= 0 && chargeFull <= 0 && energyNow <= 0 && chargeNow <= 0)
    return null

  var percent = 0
  if (!isNaN(cap) && cap >= 0)
    percent = cap
  else if (energyFull > 0 && energyNow > 0)
    percent = clampPct(100 * energyNow / energyFull)
  else if (chargeFull > 0 && chargeNow > 0)
    percent = clampPct(100 * chargeNow / chargeFull)
  else
    return null

  var status = map["POWER_SUPPLY_STATUS"] || "Unknown"
  var powerW = batteryPowerW(
    map["POWER_SUPPLY_POWER_NOW"],
    map["POWER_SUPPLY_VOLTAGE_NOW"],
    map["POWER_SUPPLY_CURRENT_NOW"]
  )
  var powerUw = powerW * 1000000

  var health = 0
  if (energyDesign > 0 && energyFull > 0)
    health = 100 * energyFull / energyDesign
  else if (chargeDesign > 0 && chargeFull > 0)
    health = 100 * chargeFull / chargeDesign

  var discharging = status === "Discharging"
  var charging = status === "Charging"
  var currentUa = Math.abs(Number(map["POWER_SUPPLY_CURRENT_NOW"]) || 0)
  var timeEmpty = 0
  var timeFull = 0
  if (discharging && powerUw > 0 && energyNow > 0)
    timeEmpty = energyNow / powerUw * 3600
  else if (discharging && chargeNow > 0)
    timeEmpty = currentUa > 0 ? chargeNow / currentUa * 3600 : 0
  if (charging && powerUw > 0 && energyFull > energyNow && energyNow > 0)
    timeFull = (energyFull - energyNow) / powerUw * 3600
  else if (charging && currentUa > 0 && chargeFull > chargeNow && chargeNow > 0)
    timeFull = (chargeFull - chargeNow) / currentUa * 3600

  return {
    present: true,
    percent: percent,
    status: status,
    powerW: powerW,
    healthPercent: health,
    cycles: Number(map["POWER_SUPPLY_CYCLE_COUNT"]) || 0,
    timeEmptySec: timeEmpty,
    timeFullSec: timeFull,
    // Energy in µWh, for combining multiple packs.
    energyNow: energyNow > 0 ? energyNow : 0,
    energyFull: energyFull > 0 ? energyFull : 0,
    energyDesign: energyDesign > 0 ? energyDesign : 0
  }
}

// Several packs (ThinkPad BAT0 + BAT1) arrive as concatenated uevent files.
// Combine them the way upower does: energy-weighted percent, summed power.
function parseBatteries(content) {
  var chunks = String(content).split(/(?=^POWER_SUPPLY_NAME=)/m)
  var packs = []
  for (var i = 0; i < chunks.length; i++) {
    if (!/POWER_SUPPLY_/.test(chunks[i])) continue
    var b = parseBattery(chunks[i])
    if (b) packs.push(b)
  }
  if (packs.length === 0) return null
  if (packs.length === 1) return packs[0]

  var now = 0, full = 0, design = 0, power = 0, cycles = 0, pctSum = 0
  var status = "Unknown"
  for (var j = 0; j < packs.length; j++) {
    var p = packs[j]
    now += p.energyNow
    full += p.energyFull
    design += p.energyDesign
    power += p.powerW
    pctSum += p.percent
    cycles = Math.max(cycles, p.cycles)
    // Any pack discharging means the system is on battery; else charging wins.
    if (p.status === "Discharging") status = "Discharging"
    else if (p.status === "Charging" && status !== "Discharging") status = "Charging"
    else if (status === "Unknown") status = p.status
  }
  var percent = full > 0 ? clampPct(100 * now / full) : Math.round(pctSum / packs.length)
  var powerUw = power * 1000000
  return {
    present: true,
    percent: percent,
    status: status,
    powerW: power,
    healthPercent: design > 0 && full > 0 ? 100 * full / design : packs[0].healthPercent,
    cycles: cycles,
    timeEmptySec: status === "Discharging" && powerUw > 0 && now > 0 ? now / powerUw * 3600 : 0,
    timeFullSec: status === "Charging" && powerUw > 0 && full > now ? (full - now) / powerUw * 3600 : 0,
    energyNow: now,
    energyFull: full,
    energyDesign: design,
    packs: packs.length
  }
}

function parseMilliC(text) {
  var v = Number(String(text).trim())
  if (!isNaN(v) && v > 0) return v / 1000
  return 0
}

function parseGpuBusy(text) {
  var v = Number(String(text).trim())
  if (!isNaN(v) && v >= 0) return Math.max(0, Math.min(100, v))
  return -1
}

// Intel iGPU busy % from an idle-residency counter (i915 rc6_residency_ms or
// xe gtidle idle_residency_ms). busy = 1 - idle_delta / wall_delta.
function gpuBusyFromIdle(idleMs, prev, nowMs) {
  var idle = Number(String(idleMs).trim())
  if (isNaN(idle) || idle < 0) return { percent: -1, prev: null }
  var next = { idle: idle, time: nowMs }
  if (!prev || !(nowMs > prev.time) || idle < prev.idle) return { percent: -1, prev: next }
  var busy = 100 * (1 - (idle - prev.idle) / (nowMs - prev.time))
  return { percent: Math.max(0, Math.min(100, busy)), prev: next }
}

// Real per-process CPU from `cat /proc/[0-9]*/stat`, diffed against the previous
// sample. (`ps pcpu` is the lifetime average, which hides what is busy *now*.)
// Returns { top: [...5], ticks: {pid: utime+stime} }.
function parseProcStats(content, prevTicks, dtSec, memTotalKb, pageSize, clkTck, limit) {
  var lines = String(content).split("\n")
  var ticks = {}
  var rows = []
  var hz = clkTck > 0 ? clkTck : 100
  var page = pageSize > 0 ? pageSize : 4096
  var memKb = memTotalKb > 0 ? memTotalKb : 0
  var n = limit > 0 ? limit : 5
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    var open = line.indexOf("(")
    var close = line.lastIndexOf(")")
    if (open < 0 || close < open) continue
    var pid = Number(line.slice(0, open).trim())
    if (!(pid > 0)) continue
    var name = line.slice(open + 1, close)
    var f = line.slice(close + 2).split(" ")
    // f[0] = state (field 3), utime = field 14, stime = 15, rss = 24
    if (f.length < 22) continue
    var t = Number(f[11]) + Number(f[12])
    ticks[pid] = t
    if (!prevTicks || !(dtSec > 0)) continue
    var p = prevTicks[pid]
    if (p === undefined) continue
    var cpu = Math.max(0, (t - p) / hz / dtSec * 100)
    var rssKb = Number(f[21]) * page / 1024
    rows.push({ pid: pid, cpu: cpu, mem: memKb > 0 ? 100 * rssKb / memKb : 0, name: name })
  }
  rows.sort(function(a, b) { return b.cpu - a.cpu || b.mem - a.mem })
  return { top: rows.slice(0, n), ticks: ticks }
}

function parseTop(content) {
  var lines = String(content).trim().split("\n")
  var out = []
  for (var i = 1; i < lines.length && out.length < 5; i++) {
    var f = lines[i].trim().split(/\s+/)
    if (f.length < 4) continue
    var comm = f.slice(3).join(" ")
    if (comm === "ps" || comm === "ps.bin") continue
    out.push({
      pid: Number(f[0]),
      cpu: Number(f[1]),
      mem: Number(f[2]),
      name: comm
    })
  }
  return out
}

var SKIP_FS = {
  tmpfs: true, devtmpfs: true, squashfs: true, overlay: true, proc: true,
  sysfs: true, cgroup: true, cgroup2: true, autofs: true, efivarfs: true,
  fusectl: true, debugfs: true, tracefs: true, securityfs: true, ramfs: true,
  hugetlbfs: true, mqueue: true, configfs: true, pstore: true, bpf: true,
  nsfs: true, devpts: true, binfmt_misc: true,
  // Read-only / always-100% images (ISO sticks, snaps) would trip the full alert.
  iso9660: true, udf: true, erofs: true, "fuse.portal": true, "fuse.gvfsd-fuse": true
}

// Removable media: shown in the popup, but never trips the "disk full" alert.
function isRemovableMount(target) {
  return /^\/(run\/)?media\//.test(String(target))
}

function parseDf(content) {
  var lines = String(content).trim().split("\n")
  var bySource = {}
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (!line || /^Filesystem\b/i.test(line) || /^source\b/i.test(line)) continue
    var f = line.split(/\s+/)
    if (f.length < 5) continue
    var source = f[0]
    var target = f[1]
    var fstype = f[2]
    var size = Number(f[3])
    var used = Number(f[4])
    if (SKIP_FS[fstype]) continue
    if (!(size > 0)) continue
    var row = {
      source: source,
      target: target,
      fstype: fstype,
      total: size,
      used: used,
      percent: 100 * used / size
    }
    var prev = bySource[source]
    if (!prev || target === "/" || (prev.target !== "/" && target.length < prev.target.length))
      bySource[source] = row
  }
  var out = []
  for (var src in bySource) out.push(bySource[src])
  out.sort(function(a, b) {
    if (a.target === "/") return -1
    if (b.target === "/") return 1
    return a.target < b.target ? -1 : 1
  })
  if (out.length > 6) out = out.slice(0, 6)
  return out
}

function hottestDisk(disks) {
  var max = 0
  for (var i = 0; i < disks.length; i++) {
    if (isRemovableMount(disks[i].target)) continue
    if (disks[i].percent > max) max = disks[i].percent
  }
  return max
}

// Latching threshold: trips at `on`, clears only once below `off`.
function hysteresis(active, value, on, off) {
  return active ? value >= off : value >= on
}

function clampInt(v, lo, hi, fallback) {
  var n = Math.round(Number(v))
  if (isNaN(n)) return fallback
  return Math.max(lo, Math.min(hi, n))
}

function fmtDuration(sec) {
  var s = Math.floor(sec)
  var h = Math.floor(s / 3600)
  var m = Math.floor((s % 3600) / 60)
  return h > 0 ? h + "h " + m + "m" : m + "m"
}

function rootDisk(disks) {
  if (!disks || disks.length === 0) return null
  for (var i = 0; i < disks.length; i++)
    if (disks[i].target === "/") return disks[i]
  var minLarge = 8 * 1073741824
  for (var j = 0; j < disks.length; j++)
    if (disks[j].total >= minLarge) return disks[j]
  return disks[0]
}

function parseDiscover(content) {
  var out = { cpu: "", nvme: "", gpu: "", gpuIdle: "", gpuRuntime: "", bat: "", bats: [], vramUsed: "", vramTotal: "", vramSmi: false, clkTck: 100, pageSize: 4096 }
  var lines = String(content).trim().split("\n")
  for (var i = 0; i < lines.length; i++) {
    var parts = lines[i].split(" ")
    if (parts.length < 2) continue
    if (parts[0] === "cpu") out.cpu = parts[1]
    else if (parts[0] === "nvme") out.nvme = parts[1]
    else if (parts[0] === "gpu") out.gpu = parts[1]
    else if (parts[0] === "bat") {
      if (!out.bat) out.bat = parts[1]
      out.bats.push(parts[1])
    }
    else if (parts[0] === "gpuidle") {
      out.gpuIdle = parts[1]
      if (parts.length >= 3) out.gpuRuntime = parts[2]
    }
    else if (parts[0] === "clk") out.clkTck = Number(parts[1]) || 100
    else if (parts[0] === "page") out.pageSize = Number(parts[1]) || 4096
    else if (parts[0] === "vram" && parts.length >= 3) {
      out.vramUsed = parts[1]
      out.vramTotal = parts[2]
    } else if (parts[0] === "vram_smi") out.vramSmi = true
  }
  return out
}

function packetLoss(text) {
  var m = String(text).match(/([\d.]+)% packet loss/)
  return m ? Number(m[1]) : 100
}

var PROC_STAT_SCRIPT = "cat /proc/[0-9]*/stat 2>/dev/null"

// timeout: a stale NFS/SMB mount must not wedge the sampler.
var DF_SCRIPT = "timeout 5 df -B1 --output=source,target,fstype,size,used -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs -x proc -x sysfs 2>/dev/null"

var DISCOVER_SCRIPT =
  "cpu=\"\"; nvme=\"\"; gpu=\"\"; " +
  "pick_cpu_label() { " +
  "  local d=\"$1\" pat=\"$2\"; local f; " +
  "  f=$(grep -lE \"$pat\" \"$d\"/temp*_label 2>/dev/null | head -1); " +
  "  if [ -n \"$f\" ]; then echo \"${f%_label}_input\"; " +
  "  elif [ -f \"$d/temp1_input\" ]; then echo \"$d/temp1_input\"; fi; " +
  "}; " +
  "for d in /sys/class/hwmon/hwmon*; do " +
  "  n=$(cat \"$d/name\" 2>/dev/null); " +
  "  case \"$n\" in " +
  "    coretemp) [ -z \"$cpu\" ] && cpu=$(pick_cpu_label \"$d\" \"Package id 0\");; " +
  "    k10temp|zenpower) [ -z \"$cpu\" ] && cpu=$(pick_cpu_label \"$d\" \"Tctl|Tdie\");; " +
  "    nvme|drivetemp) [ -z \"$nvme\" ] && [ -f \"$d/temp1_input\" ] && nvme=\"$d/temp1_input\";; " +
  "  esac; " +
  "done; " +
  "if [ -z \"$cpu\" ]; then " +
  "  for d in /sys/class/hwmon/hwmon*; do " +
  "    n=$(cat \"$d/name\" 2>/dev/null); " +
  "    case \"$n\" in cpu|cpu_thermal|soc_thermal|soc) " +
  "      [ -f \"$d/temp1_input\" ] && cpu=\"$d/temp1_input\" && break;; " +
  "    esac; " +
  "  done; " +
  "fi; " +
  "if [ -z \"$cpu\" ]; then " +
  "  for d in /sys/class/hwmon/hwmon*; do " +
  "    n=$(cat \"$d/name\" 2>/dev/null); " +
  "    if [ \"$n\" = \"acpitz\" ] && [ -f \"$d/temp1_input\" ]; then cpu=\"$d/temp1_input\"; break; fi; " +
  "  done; " +
  "fi; " +
  "[ -n \"$cpu\" ] && echo \"cpu $cpu\"; " +
  "[ -n \"$nvme\" ] && echo \"nvme $nvme\"; " +
  "bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1); " +
  "if [ -z \"$bat\" ]; then " +
  "  for p in /sys/class/power_supply/*; do " +
  "    [ \"$(cat \"$p/type\" 2>/dev/null)\" = \"Battery\" ] || continue; " +
  "    [ \"$(cat \"$p/scope\" 2>/dev/null)\" = \"Device\" ] && continue; " +
  "    bat=\"$p\" && break; " +
  "  done; " +
  "fi; " +
  "[ -n \"$bat\" ] && echo \"bat $bat/uevent\"; " +
  // Extra system packs (BAT1…); skip peripherals (mouse/keyboard: scope=Device).
  "for p in /sys/class/power_supply/*; do " +
  "  [ \"$p\" = \"$bat\" ] && continue; " +
  "  [ \"$(cat \"$p/type\" 2>/dev/null)\" = \"Battery\" ] || continue; " +
  "  [ \"$(cat \"$p/scope\" 2>/dev/null)\" = \"Device\" ] && continue; " +
  "  echo \"bat $p/uevent\"; " +
  "done; " +
  "gpu=\"\"; " +
  "for c in /sys/class/drm/card*/device/gpu_busy_percent; do " +
  "  [ -f \"$c\" ] && gpu=\"$c\" && echo \"gpu $c\" && break; " +
  "done; " +
  "if [ -z \"$gpu\" ]; then " +
  "  for c in /sys/class/drm/card[0-9]*; do " +
  "    for f in \"$c/device/tile0/gt0/gtidle/idle_residency_ms\" \"$c/gt/gt0/rc6_residency_ms\" \"$c/power/rc6_residency_ms\"; do " +
  "      [ -r \"$f\" ] && echo \"gpuidle $f $c/device/power/runtime_status\" && break 2; " +
  "    done; " +
  "  done; " +
  "fi; " +
  "echo \"clk $(getconf CLK_TCK 2>/dev/null || echo 100)\"; " +
  "echo \"page $(getconf PAGESIZE 2>/dev/null || echo 4096)\"; " +
  "vram_used=\"\"; vram_total=\"\"; vram_best=0; " +
  "for d in /sys/class/drm/card*/device; do " +
  "  [ -f \"$d/mem_info_vram_used\" ] && [ -f \"$d/mem_info_vram_total\" ] || continue; " +
  "  tot=$(cat \"$d/mem_info_vram_total\" 2>/dev/null); " +
  "  [ \"$tot\" -gt \"$vram_best\" ] 2>/dev/null || continue; " +
  "  vram_best=$tot; vram_used=\"$d/mem_info_vram_used\"; vram_total=\"$d/mem_info_vram_total\"; " +
  "done; " +
  "if [ -n \"$vram_used\" ]; then echo \"vram $vram_used $vram_total\"; " +
  "elif command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then echo \"vram_smi 1\"; " +
  "fi"
