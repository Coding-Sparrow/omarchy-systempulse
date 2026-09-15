#!/usr/bin/env node
// Run: node test/model-test.js
"use strict"

const fs = require("fs")
const path = require("path")

const src = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
const api = {}
const fn = new Function(
  "exports",
  src +
    "\nObject.assign(exports, {" +
    "clampPct, speed, speedShort, pushHistory, historyLabel," +
    "parseStat, parseLoadavg, parseUptime, parseCpuinfo, parseScalingFreq," +
    "parseMeminfo, discoverDiskDevices, parseDiskstats," +
    "parseNetDev, parseV4DefaultIface, parseV6DefaultIface, netRates," +
    "parseBattery, batteryPowerW, normalizeWatts, parseVramBytes, parseVramSmi," +
    "parseMilliC, parseGpuBusy, parseTop, parseDf, hottestDisk, rootDisk," +
    "parseDiscover, packetLoss" +
    "});"
)
fn(api)

let failed = 0
function eq(name, got, want) {
  const gs = JSON.stringify(got)
  const ws = JSON.stringify(want)
  if (gs === ws) {
    console.log("ok  " + name)
    return
  }
  failed++
  console.log("FAIL " + name)
  console.log("  got  " + gs)
  console.log("  want " + ws)
}

function near(name, got, want, eps) {
  if (typeof got === "number" && Math.abs(got - want) <= (eps || 1e-6)) {
    console.log("ok  " + name)
    return
  }
  failed++
  console.log("FAIL " + name + " got=" + got + " want=" + want)
}

eq("clampPct high", api.clampPct(140), 100)
eq("clampPct low", api.clampPct(-3), 0)
eq("speed bytes", api.speed(500), "500 B/s")
eq("speedShort k", api.speedShort(22 * 1024), "22k")
eq("history filling", api.historyLabel(2000, 2), "filling…")
eq("history seconds", api.historyLabel(2000, 20), "last 38s")
eq("history minutes", api.historyLabel(2000, 120), "last ~4 min")

const hist = api.pushHistory([1, 2], 3, 3)
eq("pushHistory grow", hist, [1, 2, 3])
eq("pushHistory ring", api.pushHistory([1, 2, 3], 4, 3), [2, 3, 4])

const stat1 = api.parseStat("cpu  100 0 0 100 0 0 0 0\ncpu0 50 0 0 50 0 0 0 0\n", null, [])
eq("parseStat first hadPrev", stat1 && stat1.hadPrev, false)
const stat2 = api.parseStat("cpu  150 0 0 110 0 0 0 0\ncpu0 80 0 0 55 0 0 0 0\n", stat1.prevCpu, stat1.prevCores)
eq("parseStat second hadPrev", stat2 && stat2.hadPrev, true)
near("parseStat percent", stat2.cpuPercent, 83, 0.5) // 50 busy of 60 total

eq("loadavg", api.parseLoadavg("0.10 0.20 0.30 1/200 1\n"), "0.10 0.20 0.30")
eq("uptime", api.parseUptime("123.4 456.7\n"), 123.4)
eq("cpuinfo mhz", api.parseCpuinfo("processor : 0\ncpu MHz : 2000.0\nprocessor : 1\ncpu MHz : 1000.0\n").freqGhz, 1.5)
eq("cpuinfo none", api.parseCpuinfo("processor : 0\n").haveMhz, false)
eq("scaling freq", api.parseScalingFreq("2500000\n"), 2.5)

const mem = api.parseMeminfo("MemTotal: 1000000 kB\nMemAvailable: 250000 kB\nCached: 100000 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\n")
near("mem percent", mem.memPercent, 75, 0.01)

const df = api.parseDf(
  "Filesystem Mounted Type 1B-blocks Used\n" +
    "/dev/mapper/root / btrfs 1000 100\n" +
    "/dev/mapper/root /home btrfs 1000 100\n" +
    "/dev/nvme0n1p1 /boot vfat 200 20\n" +
    "tmpfs /tmp tmpfs 100 10\n"
)
eq("parseDf count", df.length, 2)
eq("parseDf prefers /", df[0].target, "/")
eq("parseDf extra", df[1].target, "/boot")
near("hottestDisk", api.hottestDisk(df), 10, 0.01)
eq("rootDisk is /", api.rootDisk(df) && api.rootDisk(df).target, "/")

const chargeBat = api.parseBattery(
  "POWER_SUPPLY_CAPACITY=40\nPOWER_SUPPLY_STATUS=Discharging\n" +
    "POWER_SUPPLY_CHARGE_NOW=2000000\nPOWER_SUPPLY_CHARGE_FULL=4000000\n" +
    "POWER_SUPPLY_CHARGE_FULL_DESIGN=5000000\nPOWER_SUPPLY_CURRENT_NOW=1000000\n"
)
eq("battery percent", chargeBat.percent, 40)
eq("battery health", Math.round(chargeBat.healthPercent), 80)
near("battery time h", chargeBat.timeEmptySec, 7200, 1)

const powerBat = api.parseBattery(
  "POWER_SUPPLY_CAPACITY=35\nPOWER_SUPPLY_STATUS=Charging\n" +
    "POWER_SUPPLY_POWER_NOW=21513339\n"
)
near("battery POWER_NOW µW to W", powerBat.powerW, 21.513339, 0.01)
near("normalize skipped µW", api.normalizeWatts(21513339), 21.513339, 0.01)
near("batteryPowerW POWER_NOW", api.batteryPowerW(21513339, 0, 0), 21.513339, 0.01)
near("batteryPowerW V*I", api.batteryPowerW(0, 11400000, 1887135), 21.513339, 0.05)

const vram = api.parseVramBytes("6442450944", "8589934592")
near("vram used Gb", vram.usedGb, 6, 0.01)
near("vram total Gb", vram.totalGb, 8, 0.01)
near("vram percent", vram.percent, 75, 0.01)
const smi = api.parseVramSmi("1234, 8192\n512, 8192\n")
near("vram smi used", smi.usedGb, (1234 + 512) / 1024, 0.01)
near("vram smi total", smi.totalGb, 16, 0.01)

eq("milliC", api.parseMilliC("49000\n"), 49)
eq("gpu busy", api.parseGpuBusy("12\n"), 12)

const top = api.parseTop("PID %CPU %MEM COMMAND\n1 0.0 0.1 systemd\n9 100 0.0 ps\n3 12.5 3.2 firefox\n")
eq("parseTop skips ps", top.map(function (p) { return p.name }), ["systemd", "firefox"])

eq(
  "v4 default",
  api.parseV4DefaultIface("Iface Destination Gateway Flags Ref Use Metric Mask MTU Window IRTT\nwlp0s20f3 00000000 0101A8C0 0003 0 0 600 00000000 0 0 0\n"),
  "wlp0s20f3"
)
eq(
  "v6 default skips lo",
  api.parseV6DefaultIface(
    "00000000000000000000000000000000 00 00000000000000000000000000000000 00 00000000000000000000000000000000 ffffffff 00000001 00000000 00200200 lo\n" +
      "00000000000000000000000000000000 00 00000000000000000000000000000000 00 fe800000000000000e8832fffeb9c1f1 00000258 00000016 00000000 00000003 wlp0s20f3\n"
  ),
  "wlp0s20f3"
)

eq("packetLoss", api.packetLoss("3 packets transmitted, 0 received, 100% packet loss"), 100)
eq(
  "discover",
  api.parseDiscover("cpu /sys/class/hwmon/hwmon6/temp1_input\nbat /sys/class/power_supply/BAT0/uevent\n"),
  {
    cpu: "/sys/class/hwmon/hwmon6/temp1_input",
    nvme: "",
    gpu: "",
    bat: "/sys/class/power_supply/BAT0/uevent",
    vramUsed: "",
    vramTotal: "",
    vramSmi: false
  }
)
eq(
  "discover vram",
  api.parseDiscover("vram /sys/class/drm/card0/device/mem_info_vram_used /sys/class/drm/card0/device/mem_info_vram_total\nvram_smi 1\n"),
  {
    cpu: "",
    nvme: "",
    gpu: "",
    bat: "",
    vramUsed: "/sys/class/drm/card0/device/mem_info_vram_used",
    vramTotal: "/sys/class/drm/card0/device/mem_info_vram_total",
    vramSmi: true
  }
)

if (failed) {
  console.log("\n" + failed + " failed")
  process.exit(1)
}
console.log("\nall passed")
