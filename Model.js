// Pure parsing/format helpers for System Pulse.
// No Qt/QML types so this can be reasoned about (and later tested) as plain JS.

function clampPct(v) {
  return Math.max(0, Math.min(100, Math.round(v)))
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

function parseDiskstats(content, diskDevices, prevDisk, now) {
  var lines = String(content).trim().split("\n")
  var readSectors = 0
  var writeSectors = 0
  for (var k = 0; k < lines.length; k++) {
    var h = lines[k].trim().split(/\s+/)
    if (h.length < 10) continue
    var name = h[2]
    if (skipDiskName(name)) continue
    if (diskDevices.indexOf(name) === -1) continue
    readSectors += Number(h[5])
    writeSectors += Number(h[9])
  }
  var readSpeed = 0
  var writeSpeed = 0
  if (prevDisk) {
    var dt = (now - prevDisk.time) / 1000
    if (dt > 0) {
      readSpeed = Math.max(0, (readSectors - prevDisk.read) * 512 / dt)
      writeSpeed = Math.max(0, (writeSectors - prevDisk.write) * 512 / dt)
    }
  }
  return {
    readSpeed: readSpeed,
    writeSpeed: writeSpeed,
    prevDisk: { time: now, read: readSectors, write: writeSectors }
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

function parseV4DefaultIface(content) {
  var lines = String(content).trim().split("\n")
  for (var i = 1; i < lines.length; i++) {
    var f = lines[i].trim().split(/\s+/)
    if (f.length >= 8 && f[1] === "00000000" && f[2] !== "00000000")
      return f[0]
  }
  return ""
}

function parseV6DefaultIface(content) {
  var lines = String(content).trim().split("\n")
  for (var i = 0; i < lines.length; i++) {
    var f = lines[i].trim().split(/\s+/)
    if (f.length < 10) continue
    if (f[0] === "00000000000000000000000000000000" && f[1] === "00" && f[9] !== "lo")
      return f[9]
  }
  return ""
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
  var voltage = Number(map["POWER_SUPPLY_VOLTAGE_NOW"]) || 0
  var powerUw = Number(map["POWER_SUPPLY_POWER_NOW"]) || 0
  if (powerUw <= 0) {
    var currentUa = Number(map["POWER_SUPPLY_CURRENT_NOW"]) || 0
    if (voltage > 0 && currentUa !== 0)
      powerUw = Math.abs(voltage * currentUa) / 1000000
  }

  var health = 0
  if (energyDesign > 0 && energyFull > 0)
    health = 100 * energyFull / energyDesign
  else if (chargeDesign > 0 && chargeFull > 0)
    health = 100 * chargeFull / chargeDesign

  var discharging = status === "Discharging"
  var timeEmpty = 0
  if (discharging && powerUw > 0 && energyNow > 0)
    timeEmpty = energyNow / powerUw * 3600
  else if (discharging && chargeNow > 0) {
    var currentUa2 = Math.abs(Number(map["POWER_SUPPLY_CURRENT_NOW"]) || 0)
    timeEmpty = currentUa2 > 0 ? chargeNow / currentUa2 * 3600 : 0
  }

  return {
    present: true,
    percent: percent,
    status: status,
    powerW: powerUw / 1000000,
    healthPercent: health,
    cycles: Number(map["POWER_SUPPLY_CYCLE_COUNT"]) || 0,
    timeEmptySec: timeEmpty
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
  nsfs: true, devpts: true, binfmt_misc: true
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
  for (var i = 0; i < disks.length; i++)
    if (disks[i].percent > max) max = disks[i].percent
  return max
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
  var out = { cpu: "", nvme: "", gpu: "", bat: "" }
  var lines = String(content).trim().split("\n")
  for (var i = 0; i < lines.length; i++) {
    var parts = lines[i].split(" ")
    if (parts.length < 2) continue
    if (parts[0] === "cpu") out.cpu = parts[1]
    else if (parts[0] === "nvme") out.nvme = parts[1]
    else if (parts[0] === "gpu") out.gpu = parts[1]
    else if (parts[0] === "bat") out.bat = parts[1]
  }
  return out
}

function packetLoss(text) {
  var m = String(text).match(/([\d.]+)% packet loss/)
  return m ? Number(m[1]) : 100
}

var DF_SCRIPT = "df -B1 --output=source,target,fstype,size,used -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs -x proc -x sysfs 2>/dev/null"

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
  "    [ \"$(cat \"$p/type\" 2>/dev/null)\" = \"Battery\" ] && bat=\"$p\" && break; " +
  "  done; " +
  "fi; " +
  "[ -n \"$bat\" ] && echo \"bat $bat/uevent\"; " +
  "for c in /sys/class/drm/card*/device/gpu_busy_percent; do " +
  "  [ -f \"$c\" ] && echo \"gpu $c\" && break; " +
  "done"
