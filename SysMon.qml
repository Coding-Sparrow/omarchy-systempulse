import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

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
  property bool haveCpuinfoMhz: false
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
  property var prevDisk: null
  property var disks: []
  property real diskPercent: 0
  property real diskUsedBytes: 0
  property real diskTotalBytes: 0

  // ---- Network
  property string netIface: ""
  property real netDown: 0
  property real netUp: 0
  property real netRxTotal: 0
  property real netTxTotal: 0
  property var prevNet: null
  property bool haveV4Default: false
  property var netDevStats: ({})

  // ---- Battery
  property bool batteryPresent: false
  property int batteryPercent: 0
  property string batteryStatus: ""
  property real batteryPowerW: 0
  property real batteryHealthPercent: 0
  property int batteryCycles: 0
  property real batteryTimeEmptySec: 0

  // ---- GPU (sysfs busy percent; hidden when undiscovered)
  property real gpuPercent: -1
  property string gpuBusyPath: ""

  // ---- Temperatures
  property real cpuTempC: 0
  property real nvmeTempC: 0

  // ---- Top processes (sampled only while the panel is open)
  property var topProcs: []

  // ---- Settings
  readonly property bool showCpu: setting("showCpu", true)
  readonly property bool showMem: setting("showMem", true)
  readonly property bool showNet: setting("showNet", true)
  readonly property bool showBattery: setting("showBattery", true)
  readonly property bool showDisk: setting("showDisk", true)
  readonly property bool showGpu: setting("showGpu", true)
  readonly property bool compactBar: setting("compactBar", false)
  readonly property bool checkConnectivity: setting("checkConnectivity", false)
  readonly property int sampleInterval: setting("interval", 2000)
  readonly property string detailCommand: setting("detailCommand", "omarchy-launch-floating-terminal-with-presentation btop")
  readonly property int alertBattery: setting("alertBattery", 20)
  readonly property int pingInterval: setting("pingInterval", 10000)
  readonly property string pingHost: setting("pingHost", "1.1.1.1")
  readonly property int pingCount: setting("pingCount", 3)
  readonly property int netAlertAfter: setting("netAlertFailures", 3)
  readonly property int alertTemp: setting("alertTemp", 85)
  readonly property int alertDisk: setting("alertDisk", 90)
  readonly property int alertMem: setting("alertMem", 95)
  readonly property bool notifications: setting("notifications", false)

  // ---- History
  property var cpuHistory: []
  property var memHistory: []
  property var netHistory: []
  property var batHistory: []
  property int historyVersion: 0
  readonly property int historyMax: 120
  readonly property string historySpan: {
    var _tick = historyVersion
    return Model.historyLabel(sampleInterval, cpuHistory.length)
  }

  // ---- Bar label segments
  readonly property color urgentCol: root.bar ? root.bar.urgent : Color.urgent
  property string focusSection: ""
  property string hoveredSection: ""

  function cpuSegText() {
    return compactBar ? (cpuPercent + "%") : ("CPU " + cpuPercent + "%")
  }
  function memSegText() {
    return compactBar ? (Math.round(memPercent) + "%") : ("MEM " + Math.round(memPercent) + "%")
  }
  function gpuSegText() {
    var pct = gpuPercent < 0 ? 0 : Math.round(gpuPercent)
    return compactBar ? ("G " + pct + "%") : ("GPU " + pct + "%")
  }
  function batSegText() {
    return compactBar ? (batteryPercent + "%") : ("BAT " + batteryPercent + "%")
  }
  function diskSegText() {
    return compactBar ? (Math.round(diskPercent) + "%") : ("DISK " + Math.round(diskPercent) + "%")
  }

  readonly property var barSegments: {
    var segs = []
    if (showCpu) segs.push({ id: "cpu", text: cpuSegText(), alert: cpuAlert })
    if (showMem) segs.push({ id: "mem", text: memSegText(), alert: memAlert })
    if (showGpu && gpuPercent >= 0) segs.push({ id: "cpu", text: gpuSegText(), alert: false })
    if (showDisk && diskTotalBytes > 0) segs.push({ id: "disk", text: diskSegText(), alert: diskAlert })
    if (showNet && netIface !== "") segs.push({ id: "net", text: "\u2193" + Model.speedShort(netDown) + " \u2191" + Model.speedShort(netUp), alert: netAlert })
    if (showBattery && batteryPresent) segs.push({ id: "battery", text: batSegText(), alert: batteryAlert })
    return segs
  }

  property int netFailures: 0
  property real packetLoss: 0
  readonly property bool netAlert: checkConnectivity && showNet && netIface !== "" && netFailures >= netAlertAfter
  readonly property bool batteryAlert: showBattery && batteryPresent && batteryStatus === "Discharging" && batteryPercent > 0 && batteryPercent <= alertBattery
  readonly property bool cpuAlert: cpuTempC >= alertTemp
  readonly property bool memAlert: showMem && memPercent >= alertMem
  readonly property bool diskAlert: diskPercent >= alertDisk
  readonly property bool alertActive: batteryAlert || cpuAlert || memAlert || diskAlert || netAlert
  property var activeAlerts: ({})

  property string cpuTempPath: ""
  property string nvmeTempPath: ""
  property string batteryPath: ""

  readonly property string tooltip: {
    var parts = []
    parts.push("CPU " + cpuPercent + "%")
    if (memTotalGb > 0) parts.push("Memory " + memUsedGb.toFixed(1) + " / " + memTotalGb.toFixed(1) + " GB")
    if (gpuPercent >= 0) parts.push("GPU " + Math.round(gpuPercent) + "%")
    if (showNet && netIface !== "") parts.push("\u2193" + Model.speed(netDown) + " \u2191" + Model.speed(netUp))
    if (batteryPresent) parts.push("BAT " + batteryPercent + "% " + batteryStatus)
    if (cpuTempC > 0) parts.push("CPU " + Math.round(cpuTempC) + "\u00B0C")
    return parts.join("  ·  ")
  }

  function speed(bps) { return Model.speed(bps) }
  function speedShort(bps) { return Model.speedShort(bps) }

  function checkAlerts() {
    var alerts = []
    if (batteryAlert)
      alerts.push(["battery", "Battery low: " + batteryPercent + "%"])
    if (cpuAlert)
      alerts.push(["temp", "CPU hot: " + Math.round(cpuTempC) + "°C"])
    if (memAlert)
      alerts.push(["mem", "Memory high: " + Math.round(memPercent) + "%"])
    if (netAlert)
      alerts.push(["net", packetLoss >= 100 ? "Network down: 100% packet loss" : "Network issue: " + Math.round(packetLoss) + "% packet loss"])
    if (diskAlert) {
      var name = "/"
      for (var d = 0; d < disks.length; d++) {
        if (disks[d].percent >= alertDisk) { name = disks[d].target; break }
      }
      alerts.push(["disk", "Disk almost full: " + name + " " + Math.round(diskPercent) + "%"])
    }

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

  function refresh() { sample() }

  function sample() {
    statFile.reload()
    loadavgFile.reload()
    uptimeFile.reload()
    cpuinfoFile.reload()
    freqFile.reload()
    memFile.reload()
    diskstatsFile.reload()
    netDevFile.reload()
    routeFile.reload()
    ipv6RouteFile.reload()
    if (batteryPath !== "") batFile.reload()
    if (cpuTempPath !== "") cpuTempFile.reload()
    if (nvmeTempPath !== "") nvmeTempFile.reload()
    if (gpuBusyPath !== "") gpuBusyFile.reload()
  }

  function applyStat(content) {
    var r = Model.parseStat(content, prevCpu, prevCores)
    if (!r) return
    if (r.hadPrev) cpuPercent = r.cpuPercent
    prevCpu = r.prevCpu
    cores = r.cores
    prevCores = r.prevCores
    Model.pushHistory(cpuHistory, cpuPercent, historyMax)
  }

  function applyMem(content) {
    var r = Model.parseMeminfo(content)
    cachedGb = r.cachedGb
    memTotalGb = r.memTotalGb
    memUsedGb = r.memUsedGb
    memPercent = r.memPercent
    swapTotalGb = r.swapTotalGb
    swapUsedGb = r.swapUsedGb
    swapPercent = r.swapPercent
    Model.pushHistory(memHistory, memPercent, historyMax)
  }

  function applyDiskstats(content) {
    if (diskDevices === null) {
      diskDevices = Model.discoverDiskDevices(content)
      return
    }
    var r = Model.parseDiskstats(content, diskDevices, prevDisk, new Date().getTime())
    diskReadSpeed = r.readSpeed
    diskWriteSpeed = r.writeSpeed
    prevDisk = r.prevDisk
  }

  function applyNetDev(content) {
    netDevStats = Model.parseNetDev(content)
    var r = Model.netRates(netIface, netDevStats, prevNet, new Date().getTime())
    if (!r) return
    netDown = r.down
    netUp = r.up
    netRxTotal = r.rxTotal
    netTxTotal = r.txTotal
    prevNet = r.prevNet
    Model.pushHistory(netHistory, netDown + netUp, historyMax)
  }

  function setNetIface(name) {
    if (!name || name === "lo") return
    if (netIface !== name) {
      netIface = name
      prevNet = null
    }
  }

  function applyBattery(content) {
    var r = Model.parseBattery(content)
    if (!r) return
    batteryPresent = true
    batteryPercent = r.percent
    batteryStatus = r.status
    batteryPowerW = r.powerW
    batteryHealthPercent = r.healthPercent
    batteryCycles = r.cycles
    batteryTimeEmptySec = r.timeEmptySec
    Model.pushHistory(batHistory, batteryPercent, historyMax)
  }

  FileView { id: statFile; path: "/proc/stat"; watchChanges: false; printErrors: false; onLoaded: root.applyStat(text()) }
  FileView { id: loadavgFile; path: "/proc/loadavg"; watchChanges: false; printErrors: false; onLoaded: root.loadAvg = Model.parseLoadavg(text()) }
  FileView { id: uptimeFile; path: "/proc/uptime"; watchChanges: false; printErrors: false; onLoaded: root.uptimeSec = Model.parseUptime(text()) }
  FileView { id: cpuinfoFile; path: "/proc/cpuinfo"; watchChanges: false; printErrors: false; onLoaded: {
    var r = Model.parseCpuinfo(text())
    root.haveCpuinfoMhz = r.haveMhz
    if (r.haveMhz) root.freqGhz = r.freqGhz
  } }
  FileView { id: freqFile; path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"; watchChanges: false; printErrors: false; onLoaded: {
    if (!root.haveCpuinfoMhz) {
      var ghz = Model.parseScalingFreq(text())
      if (ghz > 0) root.freqGhz = ghz
    }
  } }
  FileView { id: memFile; path: "/proc/meminfo"; watchChanges: false; printErrors: false; onLoaded: root.applyMem(text()) }
  FileView { id: diskstatsFile; path: "/proc/diskstats"; watchChanges: false; printErrors: false; onLoaded: root.applyDiskstats(text()) }
  FileView { id: netDevFile; path: "/proc/net/dev"; watchChanges: false; printErrors: false; onLoaded: root.applyNetDev(text()) }
  FileView { id: routeFile; path: "/proc/net/route"; watchChanges: false; printErrors: false; onLoaded: {
    var iface = Model.parseV4DefaultIface(text())
    root.haveV4Default = iface !== ""
    if (iface) root.setNetIface(iface)
  } }
  FileView { id: ipv6RouteFile; path: "/proc/net/ipv6_route"; watchChanges: false; printErrors: false; onLoaded: {
    if (root.haveV4Default) return
    var iface = Model.parseV6DefaultIface(text())
    if (iface) root.setNetIface(iface)
  } }

  FileView {
    id: batFile
    path: root.batteryPath
    watchChanges: false
    printErrors: false
    onLoaded: root.applyBattery(text())
    onLoadFailed: root.batteryPresent = false
  }

  FileView {
    id: cpuTempFile
    path: root.cpuTempPath
    watchChanges: false
    printErrors: false
    onLoaded: { var v = Model.parseMilliC(text()); if (v > 0) root.cpuTempC = v }
  }

  FileView {
    id: nvmeTempFile
    path: root.nvmeTempPath
    watchChanges: false
    printErrors: false
    onLoaded: { var v = Model.parseMilliC(text()); if (v > 0) root.nvmeTempC = v }
  }

  FileView {
    id: gpuBusyFile
    path: root.gpuBusyPath
    watchChanges: false
    printErrors: false
    onLoaded: { var v = Model.parseGpuBusy(text()); if (v >= 0) root.gpuPercent = v }
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
    command: ["bash", "-c", Model.DF_SCRIPT]
    stdout: StdioCollector {
      id: dfOut
      waitForEnd: true
      onStreamFinished: {
        var list = Model.parseDf(dfOut.text)
        root.disks = list
        root.diskPercent = Model.hottestDisk(list)
        for (var i = 0; i < list.length; i++) {
          if (list[i].target === "/") {
            root.diskUsedBytes = list[i].used
            root.diskTotalBytes = list[i].total
            break
          }
        }
        if (list.length > 0 && root.diskTotalBytes <= 0) {
          root.diskUsedBytes = list[0].used
          root.diskTotalBytes = list[0].total
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

  Process { id: notifyProc }
  Process { id: dismissProc }

  Process {
    id: pingProc
    command: ["ping", "-c", String(root.pingCount), "-W", "1", root.pingHost]
    stdout: StdioCollector {
      id: pingOut
      waitForEnd: true
      onStreamFinished: root.packetLoss = Model.packetLoss(pingOut.text)
    }
    onExited: function(exitCode) {
      var ok = exitCode === 0 && root.packetLoss < 100
      root.netFailures = ok ? 0 : root.netFailures + 1
    }
  }

  Timer {
    interval: root.pingInterval
    running: root.checkConnectivity && root.showNet && root.netIface !== "" && !pingProc.running
    repeat: true
    onTriggered: pingProc.running = true
  }

  Process {
    id: topProc
    command: ["ps", "-eo", "pid,pcpu,pmem,comm", "--sort=-pcpu"]
    stdout: StdioCollector {
      id: topOut
      waitForEnd: true
      onStreamFinished: root.topProcs = Model.parseTop(topOut.text)
    }
  }

  Timer {
    interval: 3000
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!topProc.running) topProc.running = true
    }
  }

  Process {
    id: discoverProc
    command: ["bash", "-c", Model.DISCOVER_SCRIPT]
    stdout: StdioCollector {
      id: discoverOut
      waitForEnd: true
      onStreamFinished: {
        var d = Model.parseDiscover(discoverOut.text)
        if (d.cpu) root.cpuTempPath = d.cpu
        if (d.nvme) root.nvmeTempPath = d.nvme
        if (d.gpu) root.gpuBusyPath = d.gpu
        if (d.bat) {
          root.batteryPath = d.bat
          root.batteryPresent = true
        }
      }
    }
  }
  Component.onCompleted: discoverProc.running = true

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "coding-sparrow.systempulse"

    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.broadcast("openPanel") }
    function close(): void { root.broadcast("closePanel") }
    function toggle(): void { root.broadcast("togglePanel") }
  }

  function openSection(id) {
    focusSection = id || ""
    if (panelLoader.item && panelLoader.item.revealSection)
      panelLoader.item.revealSection(id)
    openPanel()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: root.barSegments.length > 0
    fixedHeight: root.vertical ? root.barSegments.length * Style.bar.iconSlot : -1
    fixedWidth: root.vertical ? -1 : labelsRow.implicitWidth
    horizontalMargin: 8.75
    verticalPadding: 8.75
    tooltipText: root.tooltip

    onPressed: function(b) {
      root.dismissPulseToasts()
      if (b === Qt.RightButton) {
        if (root.bar) root.bar.run(root.detailCommand)
        return
      }
      if (root.hoveredSection) {
        root.openSection(root.hoveredSection)
        return
      }
      root.focusSection = ""
      if (panelLoader.item && panelLoader.item.revealSection)
        panelLoader.item.revealSection("")
      root.togglePanel()
    }

    Row {
      id: labelsRow
      visible: !root.vertical
      anchors.centerIn: parent
      spacing: Style.spaceReal(8)
      z: 2

      Canvas {
        id: miniSpark
        visible: root.showCpu && root.cpuHistory.length >= 2
        width: visible ? 40 : 0
        height: Math.max(12, button.fontSize)
        antialiasing: true
        property int rev: root.historyVersion
        onRevChanged: requestPaint()
        onVisibleChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          var data = root.cpuHistory
          if (!data || data.length < 2) return
          var n = data.length
          ctx.beginPath()
          for (var j = 0; j < n; j++) {
            var x = width * j / (n - 1)
            var y = height - 1 - (height - 2) * Math.min(1, data[j] / 100)
            if (j === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
          }
          ctx.strokeStyle = root.cpuAlert ? root.urgentCol : button.foreground
          ctx.lineWidth = 1.25
          ctx.stroke()
        }
        HoverHandler {
          onHoveredChanged: {
            if (hovered) root.hoveredSection = "cpu"
            else if (root.hoveredSection === "cpu") root.hoveredSection = ""
          }
        }
      }

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

          HoverHandler {
            onHoveredChanged: {
              if (hovered) root.hoveredSection = modelData.id
              else if (root.hoveredSection === modelData.id) root.hoveredSection = ""
            }
          }
        }
      }
    }

    Column {
      visible: root.vertical
      anchors.fill: parent
      z: 2

      Repeater {
        model: root.barSegments

        Item {
          required property var modelData
          width: button.width
          height: Style.bar.iconSlot

          OpticalGlyph {
            anchors.fill: parent
            text: modelData.text
            fontFamily: button.fontFamily
            fontSize: String(modelData.text).length > 3 ? button.fontSize * 0.9 : button.fontSize
            color: modelData.alert ? root.urgentCol : button.foreground
          }

          HoverHandler {
            onHoveredChanged: {
              if (hovered) root.hoveredSection = modelData.id
              else if (root.hoveredSection === modelData.id) root.hoveredSection = ""
            }
          }
        }
      }
    }
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

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
