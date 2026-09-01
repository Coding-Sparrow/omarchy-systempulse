import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "coding-sparrow.systempulse"
  ipcTarget: "coding-sparrow.systempulse"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var hw: hostWidget
  readonly property var barIdentity: hostWidget || root

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string fam: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(fg, 1.5)
  readonly property color track: Qt.rgba(fg.r, fg.g, fg.b, 0.12)
  readonly property real colWidth: (contentCol.width - Style.space(14)) / 2

  property string localIp: ""
  property string focusSection: ""

  function revealSection(id) {
    focusSection = id || ""
    if (id) highlightTimer.restart()
    else highlightTimer.stop()
    Qt.callLater(function() { root.scrollToSection(id) })
  }

  function sectionItem(id) {
    if (id === "cpu") return cpuBox
    if (id === "mem" || id === "disk") return memBox
    if (id === "net") return netCol
    if (id === "battery") return batCol
    return null
  }

  function scrollToSection(id) {
    if (!id || !flick) return
    var item = sectionItem(id)
    if (!item) return
    var y = item.mapToItem(contentCol, 0, 0).y
    var maxY = Math.max(0, flick.contentHeight - flick.height)
    flick.contentY = Math.max(0, Math.min(y - Style.space(8), maxY))
  }

  function headingColor(id) {
    if (focusSection === id) return Style.selectedStateColor(root.fg, Color.accent)
    return root.dim
  }

  function headingText(id, label) {
    return focusSection === id ? "\u25B6  " + label : label
  }

  readonly property color focusFill: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.14)

  Timer {
    id: highlightTimer
    interval: 2800
    onTriggered: root.focusSection = ""
  }

  function open() {
    root.controller.show()
    refreshOnce()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else open()
  }

  function refreshOnce() {
    var dev = root.hw && root.hw.netIface ? String(root.hw.netIface).replace(/[^A-Za-z0-9._-]/g, "") : ""
    var script = dev !== ""
      ? "ip -4 -o addr show dev " + dev + " scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1"
      : "hostname -I 2>/dev/null | awk '{print $1}'"
    ipProc.command = ["bash", "-c", script]
    ipProc.running = true
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  onOpenedChanged: {
    if (opened) refreshOnce()
  }

  function fmtGb(v) {
    return v.toFixed(1) + " GB"
  }

  function fmtUptime(sec) {
    var s = Math.floor(sec)
    var d = Math.floor(s / 86400)
    var h = Math.floor((s % 86400) / 3600)
    var m = Math.floor((s % 3600) / 60)
    if (d > 0) return d + "d " + h + "h"
    if (h > 0) return h + "h " + m + "m"
    return m + "m"
  }

  function fmtSpeed(bps) {
    if (bps < 1024) return Math.round(bps) + " B/s"
    if (bps < 1048576) return (bps / 1024).toFixed(bps < 10240 ? 1 : 0) + " kB/s"
    return (bps / 1048576).toFixed(1) + " MB/s"
  }

  Process {
    id: ipProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.localIp = String(text).trim()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(contentCol.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
    }

    Flickable {
      id: flick
      anchors.fill: parent
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      contentWidth: width
      contentHeight: contentCol.implicitHeight
      interactive: contentHeight > height + 1
      flickableDirection: Flickable.VerticalFlick

    Column {
      id: contentCol
      width: flick.width
      spacing: Style.space(12)

      // ================================================== TOP ROW: CPU | MEMORY + DISK
      Row {
        width: parent.width
        spacing: Style.space(14)

        Item {
          id: cpuBox
          width: root.colWidth
          implicitHeight: cpuCol.implicitHeight

          Rectangle {
            anchors.fill: parent
            anchors.margins: -Style.space(6)
            visible: root.focusSection === "cpu"
            color: root.focusFill
            border.color: Style.selectedStateColor(root.fg, Color.accent)
            border.width: 1
            radius: 8
          }

        Column {
          id: cpuCol
          width: parent.width
          spacing: Style.space(8)

          Text {
            text: root.headingText("cpu", "CPU")
            color: root.headingColor("cpu")
            font.family: root.fam
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
            font.bold: true
          }

          Row {
            spacing: Style.space(14)

            Text {
              anchors.baseline: parent.bottom
              text: (root.hw ? Math.round(root.hw.cpuPercent) : 0) + "%"
              color: root.fg
              font.family: root.fam
              font.pixelSize: 40
              font.bold: true
            }

            Column {
              anchors.bottom: parent.bottom
              spacing: Style.space(2)

              Text {
                text: root.hw && root.hw.loadAvg !== "" ? "Load  " + root.hw.loadAvg : "Load  —"
                color: root.fg
                font.family: root.fam
                font.pixelSize: Style.font.bodySmall
              }

              Text {
                text: {
                  if (!root.hw) return "—"
                  var bits = []
                  if (root.hw.freqGhz > 0) bits.push(root.hw.freqGhz.toFixed(2) + " GHz")
                  if (root.hw.cpuTempC > 0) bits.push(Math.round(root.hw.cpuTempC) + "\u00B0C")
                  if (root.hw.gpuPercent >= 0) bits.push("GPU " + Math.round(root.hw.gpuPercent) + "%")
                  return bits.length > 0 ? bits.join("  ·  ") : "—"
                }
                color: root.fg
                font.family: root.fam
                font.pixelSize: Style.font.bodySmall
              }
            }
          }

          Row {
            id: coreRow
            width: parent.width
            spacing: Style.space(3)
            Repeater {
              model: root.hw ? root.hw.cores : []

              Item {
                required property var modelData
                width: {
                  var n = root.hw && root.hw.cores ? root.hw.cores.length : 1
                  var gaps = Math.max(0, n - 1) * coreRow.spacing
                  return Math.max(3, (coreRow.width - gaps) / n)
                }
                height: Style.space(24)

                Rectangle {
                  anchors.fill: parent
                  radius: 2
                  color: root.track
                }

                Rectangle {
                  anchors.bottom: parent.bottom
                  width: parent.width
                  height: Math.max(2, parent.height * modelData / 100)
                  radius: 2
                  color: Style.selectedStateColor(root.fg, Color.accent)
                }
              }
            }
          }

          Text {
            visible: root.hw && root.hw.uptimeSec > 0
            text: root.hw ? ("Uptime  " + (function() {
              var s = Math.floor(root.hw.uptimeSec)
              var d = Math.floor(s / 86400)
              var h = Math.floor((s % 86400) / 3600)
              var m = Math.floor((s % 3600) / 60)
              return d > 0 ? d + "d " + h + "h" : (h > 0 ? h + "h " + m + "m" : m + "m")
            })()) : ""
            color: root.dim
            font.family: root.fam
            font.pixelSize: Style.font.bodySmall
          }
        }
        }

        Item {
          id: memBox
          width: root.colWidth
          implicitHeight: memCol.implicitHeight

          Rectangle {
            anchors.fill: parent
            anchors.margins: -Style.space(6)
            visible: root.focusSection === "mem" || root.focusSection === "disk"
            color: root.focusFill
            border.color: Style.selectedStateColor(root.fg, Color.accent)
            border.width: 1
            radius: 8
          }

        Column {
          id: memCol
          width: parent.width
          spacing: Style.space(6)

          Text {
            text: root.headingText("mem", "MEMORY")
            color: root.headingColor("mem")
            font.family: root.fam
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
            font.bold: true
          }

          Item {
            width: parent.width
            height: memUsedLabel.implicitHeight

            Text {
              id: memUsedLabel
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Used"
              color: root.dim
              font.family: root.fam
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.hw ? (root.fmtGb(root.hw.memUsedGb) + " / " + root.fmtGb(root.hw.memTotalGb) + " (" + Math.round(root.hw.memPercent) + "%)") : "—"
              color: root.fg
              font.family: root.fam
              font.pixelSize: Style.font.bodySmall
            }
          }

          Rectangle {
            width: parent.width
            height: Style.space(6)
            radius: Style.cornerRadius > 0 ? height / 2 : 0
            color: root.track

            Rectangle {
              width: Math.round(parent.width * (root.hw ? root.hw.memPercent / 100 : 0))
              height: parent.height
              radius: parent.radius
              color: Style.selectedStateColor(root.fg, Color.accent)

              Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
          }

          Text {
            text: root.hw ? ("Cached  " + root.fmtGb(root.hw.cachedGb) + "   ·   Swap  " + root.fmtGb(root.hw.swapUsedGb) + " / " + root.fmtGb(root.hw.swapTotalGb) + " (" + Math.round(root.hw.swapPercent) + "%)") : ""
            color: root.dim
            font.family: root.fam
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
            width: parent.width
          }

          Text {
            text: root.headingText("disk", "DISK")
            color: root.headingColor("disk")
            font.family: root.fam
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
            font.bold: true
          }

          Repeater {
            model: root.hw && root.hw.disks && root.hw.disks.length > 0 ? root.hw.disks : []

            Column {
              required property var modelData
              width: parent.width
              spacing: Style.space(2)

              Item {
                width: parent.width
                height: diskLabel.implicitHeight

                Text {
                  id: diskLabel
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.target
                  color: root.dim
                  font.family: root.fam
                  font.pixelSize: Style.font.bodySmall
                }

                Text {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: (modelData.used / 1073741824).toFixed(modelData.total > 10737418240 ? 0 : 1) + " / " +
                        (modelData.total / 1073741824).toFixed(modelData.total > 10737418240 ? 0 : 1) + " GB (" +
                        Math.round(modelData.percent) + "%)"
                  color: modelData.percent >= (root.hw ? root.hw.alertDisk : 90) ? (root.bar ? root.bar.urgent : Color.urgent) : root.fg
                  font.family: root.fam
                  font.pixelSize: Style.font.bodySmall
                }
              }

              Rectangle {
                width: parent.width
                height: Style.space(6)
                radius: Style.cornerRadius > 0 ? height / 2 : 0
                color: root.track

                Rectangle {
                  width: Math.round(parent.width * Math.min(1, modelData.percent / 100))
                  height: parent.height
                  radius: parent.radius
                  color: Style.selectedStateColor(root.fg, Color.accent)
                }
              }
            }
          }

          Text {
            text: root.hw ? ("Read  " + root.hw.speed(root.hw.diskReadSpeed) + "   ·   Write  " + root.hw.speed(root.hw.diskWriteSpeed) +
              (root.hw.nvmeTempC > 0 ? "   ·   " + Math.round(root.hw.nvmeTempC) + "\u00B0C" : "")) : ""
            color: root.dim
            font.family: root.fam
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
            width: parent.width
          }
        }
        }
      }

      // ================================================== MID ROW: NETWORK | BATTERY
      Row {
        width: parent.width
        spacing: Style.space(14)
        visible: (root.hw && root.hw.netIface !== "") || (root.hw && root.hw.batteryPresent)

        Column {
          id: netCol
          width: root.colWidth
          spacing: Style.space(6)
          visible: root.hw && root.hw.netIface !== ""

          Text {
            text: root.headingText("net", "NETWORK")
            color: root.headingColor("net")
            font.family: root.fam
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
            font.bold: true
          }

          Text {
            text: root.hw && root.hw.netIface !== "" ? (root.hw.netIface + "    \u2193" + root.hw.speed(root.hw.netDown) + "   \u2191" + root.hw.speed(root.hw.netUp)) : "Not connected"
            color: root.fg
            font.family: root.fam
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            text: root.hw && root.hw.netIface !== "" ? ("Since boot   \u2193" + (root.hw.netRxTotal / 1073741824).toFixed(1) + " GB   \u2191" + (root.hw.netTxTotal / 1073741824).toFixed(1) + " GB" +
              (root.localIp !== "" ? "   ·   " + root.localIp : "")) : ""
            color: root.dim
            font.family: root.fam
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
            width: parent.width
          }
        }

        Column {
          id: batCol
          width: root.colWidth
          spacing: Style.space(6)
          visible: root.hw && root.hw.batteryPresent

          Text {
            text: root.headingText("battery", "BATTERY")
            color: root.headingColor("battery")
            font.family: root.fam
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
            font.bold: true
          }

          Text {
            text: root.hw ? (root.hw.batteryPercent + "%  ·  " + root.hw.batteryStatus +
              (root.hw.batteryPowerW > 0 ? "  ·  " + root.hw.batteryPowerW.toFixed(1) + " W" : "")) : ""
            color: root.fg
            font.family: root.fam
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            text: {
              if (!root.hw) return ""
              var parts = []
              if (root.hw.batteryHealthPercent > 0) parts.push("Health " + Math.round(root.hw.batteryHealthPercent) + "%")
              if (root.hw.batteryCycles > 0) parts.push(root.hw.batteryCycles + " cycles")
              if (root.hw.batteryTimeEmptySec > 0) {
                var h = Math.floor(root.hw.batteryTimeEmptySec / 3600)
                var m = Math.floor((root.hw.batteryTimeEmptySec % 3600) / 60)
                parts.push((h > 0 ? h + "h " + m + "m" : m + "m") + " left")
              }
              return parts.join("   ·   ")
            }
            visible: text !== ""
            color: root.dim
            font.family: root.fam
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
            width: parent.width
          }
        }
      }

      // ================================================== PROCESSES
      Column {
        width: parent.width
        spacing: Style.space(6)
        visible: root.hw && root.hw.topProcs && root.hw.topProcs.length > 0

        Text {
          text: "PROCESSES"
          color: root.headingColor("cpu")
          font.family: root.fam
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
        }

        Repeater {
          model: root.hw ? root.hw.topProcs : []

          Item {
            required property var modelData
            width: contentCol.width
            height: procName.implicitHeight

            Text {
              id: procName
              anchors.left: parent.left
              anchors.right: procStats.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.name
              elide: Text.ElideRight
              color: root.fg
              font.family: root.fam
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              id: procStats
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.cpu.toFixed(1) + "% cpu   " + modelData.mem.toFixed(1) + "% mem"
              color: root.dim
              font.family: root.fam
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }

      // ================================================== HISTORY
      Column {
        width: parent.width
        spacing: Style.space(8)

        Item {
          width: parent.width
          height: histTitle.implicitHeight

          Text {
            id: histTitle
            anchors.left: parent.left
            text: "HISTORY"
            color: root.dim
            font.family: root.fam
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
            font.bold: true
          }

          Text {
            anchors.right: parent.right
            anchors.baseline: histTitle.baseline
            text: root.hw && root.hw.historySpan ? root.hw.historySpan : ""
            color: root.dim
            font.family: root.fam
            font.pixelSize: Style.font.bodySmall
          }
        }

        Loader {
          width: parent.width
          active: root.hw !== null
          source: Qt.resolvedUrl("Sparklines.qml")
          onLoaded: {
            item.hw = root.hw
            item.opened = Qt.binding(function() { return root.opened })
            item.fg = Qt.binding(function() { return root.fg })
            item.fam = Qt.binding(function() { return root.fam })
          }
        }
      }

      // ================================================== BAR DISPLAY
      Column {
        width: parent.width
        spacing: Style.space(4)

        Text {
          text: "BAR DISPLAY"
          color: root.dim
          font.family: root.fam
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
        }

        Grid {
          id: togglesGrid
          columns: 2
          width: parent.width
          columnSpacing: Style.space(12)
          rowSpacing: Style.space(2)

          Repeater {
            model: [
              { key: "showCpu", label: "CPU", fallback: true },
              { key: "showMem", label: "Memory", fallback: true },
              { key: "showNet", label: "Network", fallback: true },
              { key: "showBattery", label: "Battery", fallback: true },
              { key: "showDisk", label: "Disk", fallback: true },
              { key: "showGpu", label: "GPU", fallback: true },
              { key: "compactBar", label: "Compact bar", fallback: false },
              { key: "checkConnectivity", label: "Ping check", fallback: false },
              { key: "notifications", label: "Alert notifications", fallback: false }
            ]

            delegate: Item {
              width: (togglesGrid.width - Style.space(12)) / 2
              height: Style.space(24)

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                color: root.fg
                font.family: root.fam
                font.pixelSize: Style.font.bodySmall
              }

              ToggleSwitch {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: root.hw ? root.hw.setting(modelData.key, modelData.fallback) : false
                foreground: root.fg
                onToggled: {
                  var patch = {}
                  patch[modelData.key] = !checked
                  root.persistSettings(patch)
                }
              }
            }
          }
        }
      }
    }
    }
  }
}
