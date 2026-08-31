import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "coding-sparrow.systempulse"

  // ---- CPU
  property int cpuPercent: 0
  property var cores: []
  property var prevCores: []
  property var prevCpu: null
  property string loadAvg: ""
  property real freqGhz: 0
  property real uptimeSec: 0

  // ---- Memory
  property real memPercent: 0
  property real memUsedGb: 0
  property real memTotalGb: 0
  property real swapPercent: 0
  property real swapUsedGb: 0
  property real swapTotalGb: 0
  property real cachedGb: 0

  // ---- Disk
  property real diskReadSpeed: 0
  property real diskWriteSpeed: 0
  property var diskDevices: null

  // ---- Network
  property string netIface: ""
  property real netDown: 0
  property real netUp: 0
  property real netRxTotal: 0
  property real netTxTotal: 0
  property var prevNet: null

  // ---- Battery
  property bool batteryPresent: false
  property int batteryPercent: 0
  property string batteryStatus: ""
  property real batteryPowerW: 0
  property real batteryHealthPercent: 0
  property int batteryCycles: 0
  property real batteryTimeEmptySec: 0

  // ---- Temperatures
  property real cpuTempC: 0
  property real nvmeTempC: 0

  // ---- Settings
  readonly property bool showCpu: setting("showCpu", true)
  readonly property bool showMem: setting("showMem", true)
  readonly property bool showNet: setting("showNet", true)
  readonly property bool showBattery: setting("showBattery", true)
  readonly property int sampleInterval: setting("interval", 2000)
  readonly property string detailCommand: setting("detailCommand", "omarchy-launch-floating-terminal-with-presentation btop")
  readonly property int alertBattery: setting("alertBattery", 20)
  readonly property int pingInterval: setting("pingInterval", 10000)
  readonly property string pingHost: setting("pingHost", "1.1.1.1")
  readonly property int pingCount: setting("pingCount", 3)
  readonly property int netAlertAfter: setting("netAlertFailures", 3)
  readonly property int alertTemp: setting("alertTemp", 85)
  readonly property int alertDisk: setting("alertDisk", 90)
  readonly property bool notifications: setting("notifications", false)

  // ---- History buffers (fixed-length ring, oldest first)
  property var cpuHistory: []
  property var memHistory: []
  property var netHistory: []
  property var batHistory: []
  property int historyVersion: 0
  readonly property int historyMax: 120

  // ---- Bar label segments (real QML Text items: WidgetButton renders PlainText only)
  readonly property color urgentCol: root.bar ? root.bar.urgent : Color.urgent

  readonly property var barSegments: {
    var segs = []
    if (showCpu) segs.push({ text: "CPU " + cpuPercent + "%", alert: cpuAlert })
    if (showMem) segs.push({ text: "MEM " + Math.round(memPercent) + "%", alert: false })
    if (showNet && netIface !== "") segs.push({ text: "\u2193" + speedShort(netDown) + " \u2191" + speedShort(netUp), alert: netAlert })
    if (showBattery && batteryPresent) segs.push({ text: "BAT " + batteryPercent + "%", alert: batteryAlert })
    return segs
  }

  // ---- Connectivity probe (packet loss / ping timeout)
  property int netFailures: 0
  property real packetLoss: 0
  readonly property bool netAlert: showNet && netIface !== "" && netFailures >= netAlertAfter

  // ---- Alerts (per resource, so the bar can color only the failing segment)
  readonly property bool batteryAlert: showBattery && batteryPresent && batteryStatus === "Discharging" && batteryPercent > 0 && batteryPercent <= alertBattery
  readonly property bool cpuAlert: cpuTempC >= alertTemp
  readonly property bool alertActive: batteryAlert || cpuAlert || diskPercent >= alertDisk
  property var activeAlerts: ({})

  // ---- Disk (root filesystem, sampled slowly for alerts + panel)
  property real diskPercent: 0
  property real diskUsedBytes: 0
  property real diskTotalBytes: 0

  // ---- Paths discovered at startup
  property string cpuTempPath: ""
  property string nvmeTempPath: ""
  property string batteryPath: ""

  // ---- Bar label
  readonly property var verticalLines: {
    var lines = []
    if (showCpu) lines.push("CPU " + cpuPercent + "%")
    if (showMem) lines.push("MEM " + Math.round(memPercent) + "%")
    return lines
  }

  readonly property string tooltip: {
    var parts = []
    parts.push("CPU " + cpuPercent + "%")
    if (memTotalGb > 0) parts.push("Memory " + memUsedGb.toFixed(1) + " / " + memTotalGb.toFixed(1) + " GB")
    if (showNet && netIface !== "") parts.push("\u2193" + speed(netDown) + " \u2191" + speed(netUp))
    if (batteryPresent) parts.push("BAT " + batteryPercent + "% " + batteryStatus)
    if (cpuTempC > 0) parts.push("CPU " + Math.round(cpuTempC) + "\u00B0C")
    return parts.join("  ·  ")
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

  function clampPct(v) {
    return Math.max(0, Math.min(100, Math.round(v)))
  }

  function pushHistory(arr, value) {
    arr.push(value)
    if (arr.length > historyMax) arr.shift()
  }

  function checkAlerts() {
    var alerts = []
    if (batteryAlert)
      alerts.push(["battery", "Battery low: " + batteryPercent + "%"])
    if (cpuAlert)
      alerts.push(["temp", "CPU hot: " + Math.round(cpuTempC) + "°C"])
    if (netAlert)
      alerts.push(["net", packetLoss >= 100 ? "Network down: 100% packet loss" : "Network issue: " + Math.round(packetLoss) + "% packet loss"])
    if (diskPercent >= alertDisk)
      alerts.push(["disk", "Disk almost full: " + Math.round(diskPercent) + "%"])

    var next = {}
    for (var i = 0; i < alerts.length; i++) {
      var key = alerts[i][0]
      next[key] = true
      if (notifications && !activeAlerts[key])
        sendNotification("System Pulse — " + alerts[i][1])
    }
    activeAlerts = next
  }

  function sendNotification(message) {
    if (notifyProc.running) return
    // Clicking the toast must open the panel: the CPU-hot card sits in the
    // top-right overlay, directly over this widget, and steals bar clicks
    // until it expires (hover pauses the timer, so it can sit there forever).
    notifyProc.command = [
      "omarchy-notification-send",
      "--app-name", "System Pulse",
      "-u", "normal",
      "-t", "8000",
      message,
      "--exec", "omarchy-shell", "coding-sparrow.systempulse", "open"
    ]
    notifyProc.running = true
  }

  function dismissPulseToasts() {
    if (dismissProc.running) return
    dismissProc.command = ["omarchy-shell", "-q", "notifications", "dismiss", "System Pulse"]
    dismissProc.running = true
  }

  function refresh() {
    sample()
  }

  function sample() {
    statFile.reload()
    loadavgFile.reload()
    uptimeFile.reload()
    cpuinfoFile.reload()
    memFile.reload()
    diskstatsFile.reload()
    netDevFile.reload()
    routeFile.reload()
    if (batteryPath !== "") batFile.reload()
    if (cpuTempPath !== "") cpuTempFile.reload()
    if (nvmeTempPath !== "") nvmeTempFile.reload()
  }

  // ------------------------------------------------------------ parsing

  function parseStat(content) {
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
    if (!totals) return
    if (root.prevCpu) {
      var dT = totals.total - root.prevCpu.total
      var dB = totals.busy - root.prevCpu.busy
      if (dT > 0) root.cpuPercent = clampPct(100 * dB / dT)
    }
    root.prevCpu = totals
    pushHistory(cpuHistory, root.cpuPercent)

    var per = []
    for (var k = 0; k < newCores.length; k++) {
      var p = root.prevCores[k]
      var pct = 0
      if (p) {
        var dt = newCores[k].total - p.total
        var db = newCores[k].busy - p.busy
        if (dt > 0) pct = Math.max(0, Math.min(100, 100 * db / dt))
      }
      per.push(pct)
    }
    root.cores = per
    root.prevCores = newCores
  }

  function parseLoadavg(content) {
    var f = String(content).trim().split(/\s+/)
    if (f.length >= 3) root.loadAvg = f[0] + " " + f[1] + " " + f[2]
  }

  function parseUptime(content) {
    var f = String(content).trim().split(/\s+/)
    if (f.length >= 1) root.uptimeSec = Number(f[0])
  }

  function parseCpuinfo(content) {
    var matches = String(content).match(/cpu MHz\s*:\s*([0-9.]+)/g)
    if (!matches || matches.length === 0) return
    var sum = 0
    for (var i = 0; i < matches.length; i++) {
      sum += Number(matches[i].split(":")[1])
    }
    root.freqGhz = sum / matches.length / 1000
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
    root.cachedGb = m("Cached") / 1048576
    root.memTotalGb = totalKb / 1048576
    root.memUsedGb = (totalKb - availKb) / 1048576
    root.memPercent = totalKb > 0 ? 100 * (totalKb - availKb) / totalKb : 0
    root.swapTotalGb = swapTotalKb / 1048576
    root.swapUsedGb = (swapTotalKb - swapFreeKb) / 1048576
    root.swapPercent = swapTotalKb > 0 ? 100 * (swapTotalKb - swapFreeKb) / swapTotalKb : 0
    pushHistory(memHistory, root.memPercent)
  }

  function diskDeviceWanted(name) {
    if (/^(loop|ram|zram|sr|fd)/.test(name)) return false
    if (root.diskDevices !== null) return root.diskDevices.indexOf(name) !== -1
    return true
  }

  function parseDiskstats(content) {
    var lines = String(content).trim().split("\n")
    var now = new Date().getTime()
    var readSectors = 0
    var writeSectors = 0

    if (root.diskDevices === null) {
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
      root.diskDevices = names
      return
    }

    for (var k = 0; k < lines.length; k++) {
      var h = lines[k].trim().split(/\s+/)
      if (h.length < 10) continue
      if (!diskDeviceWanted(h[2])) continue
      readSectors += Number(h[5])
      writeSectors += Number(h[9])
    }

    if (root.prevDisk) {
      var dt = (now - root.prevDisk.time) / 1000
      if (dt > 0) {
        root.diskReadSpeed = Math.max(0, (readSectors - root.prevDisk.read) * 512 / dt)
        root.diskWriteSpeed = Math.max(0, (writeSectors - root.prevDisk.write) * 512 / dt)
      }
    }
    root.prevDisk = { time: now, read: readSectors, write: writeSectors }
  }

  property var prevDisk: null

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
    root.netDevStats = stats
    updateNet(stats)
  }

  property var netDevStats: ({})

  function parseRoute(content) {
    var lines = String(content).trim().split("\n")
    for (var i = 1; i < lines.length; i++) {
      var f = lines[i].trim().split(/\s+/)
      if (f.length >= 8 && f[1] === "00000000" && f[2] !== "00000000") {
        if (root.netIface !== f[0]) {
          root.netIface = f[0]
          root.prevNet = null
        }
        return
      }
    }
  }

  function updateNet(stats) {
    if (root.netIface === "") return
    var s = stats[root.netIface]
    if (!s) return
    var now = new Date().getTime()
    if (root.prevNet && root.prevNet.iface === root.netIface) {
      var dt = (now - root.prevNet.time) / 1000
      if (dt > 0) {
        root.netDown = Math.max(0, (s.rx - root.prevNet.rx) / dt)
        root.netUp = Math.max(0, (s.tx - root.prevNet.tx) / dt)
      }
    }
    root.prevNet = { time: now, iface: root.netIface, rx: s.rx, tx: s.tx }
    root.netRxTotal = s.rx
    root.netTxTotal = s.tx
    pushHistory(netHistory, root.netDown + root.netUp)
  }

  function parseBattery(content) {
    var map = {}
    var lines = String(content).trim().split("\n")
    for (var i = 0; i < lines.length; i++) {
      var kv = lines[i].split("=")
      if (kv.length === 2) map[kv[0]] = kv[1]
    }
    if (map["POWER_SUPPLY_CAPACITY"] === undefined) return
    root.batteryPercent = Number(map["POWER_SUPPLY_CAPACITY"]) || 0
    root.batteryStatus = map["POWER_SUPPLY_STATUS"] || "Unknown"
    var power = Number(map["POWER_SUPPLY_POWER_NOW"]) || 0
    if (power <= 0) {
      var v = Number(map["POWER_SUPPLY_VOLTAGE_NOW"]) || 0
      var c = Number(map["POWER_SUPPLY_CURRENT_NOW"]) || 0
      power = v * c
    }
    root.batteryPowerW = power / 1000000
    var design = Number(map["POWER_SUPPLY_ENERGY_FULL_DESIGN"]) || 0
    var full = Number(map["POWER_SUPPLY_ENERGY_FULL"]) || 0
    if (design > 0 && full > 0) root.batteryHealthPercent = 100 * full / design
    root.batteryCycles = Number(map["POWER_SUPPLY_CYCLE_COUNT"]) || 0
    var energyNow = Number(map["POWER_SUPPLY_ENERGY_NOW"]) || 0
    if (power > 0 && energyNow > 0)
      root.batteryTimeEmptySec = map["POWER_SUPPLY_STATUS"] === "Discharging" ? energyNow / power * 3600 : 0
    else
      root.batteryTimeEmptySec = 0
    pushHistory(batHistory, root.batteryPercent)
  }

  function parseTemp(text, target) {
    var v = Number(String(text).trim())
    if (!isNaN(v) && v > 0) target(v / 1000)
  }

  // ------------------------------------------------------------ files

  FileView { id: statFile; path: "/proc/stat"; watchChanges: false; printErrors: false; onLoaded: root.parseStat(text()) }
  FileView { id: loadavgFile; path: "/proc/loadavg"; watchChanges: false; printErrors: false; onLoaded: root.parseLoadavg(text()) }
  FileView { id: uptimeFile; path: "/proc/uptime"; watchChanges: false; printErrors: false; onLoaded: root.parseUptime(text()) }
  FileView { id: cpuinfoFile; path: "/proc/cpuinfo"; watchChanges: false; printErrors: false; onLoaded: root.parseCpuinfo(text()) }
  FileView { id: memFile; path: "/proc/meminfo"; watchChanges: false; printErrors: false; onLoaded: root.parseMeminfo(text()) }
  FileView { id: diskstatsFile; path: "/proc/diskstats"; watchChanges: false; printErrors: false; onLoaded: root.parseDiskstats(text()) }
  FileView { id: netDevFile; path: "/proc/net/dev"; watchChanges: false; printErrors: false; onLoaded: root.parseNetDev(text()) }
  FileView { id: routeFile; path: "/proc/net/route"; watchChanges: false; printErrors: false; onLoaded: root.parseRoute(text()) }

  FileView {
    id: batFile
    path: root.batteryPath
    watchChanges: false
    printErrors: false
    onLoaded: root.parseBattery(text())
    onLoadFailed: root.batteryPresent = false
  }

  FileView {
    id: cpuTempFile
    path: root.cpuTempPath
    watchChanges: false
    printErrors: false
    onLoaded: root.parseTemp(text(), function(v) { root.cpuTempC = v })
  }

  FileView {
    id: nvmeTempFile
    path: root.nvmeTempPath
    watchChanges: false
    printErrors: false
    onLoaded: root.parseTemp(text(), function(v) { root.nvmeTempC = v })
  }

  Timer {
    interval: root.sampleInterval
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.sample()
      root.checkAlerts()
      root.historyVersion++
    }
  }

  Process {
    id: dfProc
    command: ["bash", "-c", "df -B1 --output=size,used / 2>/dev/null | tail -1"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var f = String(text).trim().split(/\s+/)
        if (f.length >= 2) {
          root.diskTotalBytes = Number(f[0])
          root.diskUsedBytes = Number(f[1])
          if (root.diskTotalBytes > 0)
            root.diskPercent = 100 * root.diskUsedBytes / root.diskTotalBytes
        }
      }
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: dfProc.running = true
  }

  Process {
    id: notifyProc
  }

  Process {
    id: dismissProc
  }

  Process {
    id: pingProc
    command: ["ping", "-c", String(root.pingCount), "-W", "1", root.pingHost]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var m = String(text).match(/([\d.]+)% packet loss/)
        root.packetLoss = m ? Number(m[1]) : 100
      }
    }
    onExited: function(exitCode) {
      var ok = exitCode === 0 && root.packetLoss < 100
      root.netFailures = ok ? 0 : root.netFailures + 1
    }
  }

  Timer {
    interval: root.pingInterval
    running: root.showNet && root.netIface !== "" && !pingProc.running
    repeat: true
    onTriggered: pingProc.running = true
  }

  Process {
    id: discoverProc
    command: ["bash", "-c",
      "for d in /sys/class/hwmon/hwmon*; do " +
      "  n=$(cat \"$d/name\" 2>/dev/null); " +
      "  case \"$n\" in " +
      "    coretemp) f=$(grep -l \"Package id 0\" \"$d\"/temp*_label 2>/dev/null | head -1); " +
      "      [ -n \"$f\" ] && f=\"${f%_label}_input\" || f=\"$d/temp1_input\"; echo \"cpu $f\";; " +
      "    nvme|drivetemp) [ -f \"$d/temp1_input\" ] && echo \"nvme $d/temp1_input\";; " +
      "  esac; " +
      "done; " +
      "bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1); " +
      "[ -n \"$bat\" ] && echo \"bat $bat/uevent\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text).trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split(" ")
          if (parts.length < 2) continue
          if (parts[0] === "cpu") root.cpuTempPath = parts[1]
          else if (parts[0] === "nvme") root.nvmeTempPath = parts[1]
          else if (parts[0] === "bat") {
            root.batteryPath = parts[1]
            root.batteryPresent = true
          }
        }
      }
    }
  }
  Component.onCompleted: discoverProc.running = true

  // ------------------------------------------------------------ UI

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "coding-sparrow.systempulse"

    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.broadcast("openPanel") }
    function close(): void { root.broadcast("closePanel") }
    function toggle(): void { root.broadcast("togglePanel") }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : root.barSegments.length > 0
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    fixedWidth: root.vertical ? -1 : labelsRow.implicitWidth
    horizontalMargin: 8.75
    verticalPadding: 8.75
    tooltipText: root.tooltip

    onPressed: function(b) {
      root.dismissPulseToasts()
      if (b === Qt.RightButton) {
        if (root.bar) root.bar.run(root.detailCommand)
      } else {
        root.togglePanel()
      }
    }

    Row {
      id: labelsRow
      visible: !root.vertical
      anchors.centerIn: parent
      spacing: Style.spaceReal(8)

      Repeater {
        model: root.barSegments

        Text {
          required property var modelData
          text: modelData.text
          color: modelData.alert ? root.urgentCol : button.foreground
          font.family: button.fontFamily
          font.pixelSize: button.fontSize
          renderType: Text.NativeRendering
          verticalAlignment: Text.AlignVCenter
        }
      }
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData.length > 3 ? button.fontSize * 0.9 : button.fontSize
          color: button.foreground
        }
      }
    }
  }

  // ---- Detail popup
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  // Bar.findPanelWidget requires open/close/opened on the widget root.
  function open() { openPanel() }
  function close() { closePanel() }
  function toggle() { togglePanel() }

  function openPanel() {
    if (panelLoader.item) panelLoader.item.open()
    dismissPulseToasts()
  }

  function closePanel() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
    dismissPulseToasts()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
}
