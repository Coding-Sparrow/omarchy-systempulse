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

  property string localIp: ""

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

  function fmtTimeLeft(sec) {
    if (sec <= 0) return ""
    var h = Math.floor(sec / 3600)
    var m = Math.floor((sec % 3600) / 60)
    if (h > 0) return h + "h " + m + "m left"
    return m + "m left"
  }

  function fmtSpeed(bps) {
    if (bps < 1024) return Math.round(bps) + " B/s"
    if (bps < 1048576) return (bps / 1024).toFixed(bps < 10240 ? 1 : 0) + " kB/s"
    return (bps / 1048576).toFixed(1) + " MB/s"
  }

  Process {
    id: ipProc
    command: ["bash", "-c", "hostname -I 2>/dev/null | awk '{print $1}'"]
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
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(contentCol.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
    }

    Column {
      id: contentCol
      width: parent.width
      spacing: Style.space(12)

      // ================================================== CPU
      Column {
        width: parent.width
        spacing: Style.space(8)

        Text {
          text: "CPU"
          color: root.dim
          font.family: root.fam
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
        }

        Row {
          spacing: Style.space(18)

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
              text: root.hw ? ((root.hw.freqGhz > 0 ? root.hw.freqGhz.toFixed(2) + " GHz" : "") +
                (root.hw.cpuTempC > 0 ? "  ·  " + Math.round(root.hw.cpuTempC) + "\u00B0C" : "")) : "—"
              color: root.fg
              font.family: root.fam
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

        Row {
          spacing: Style.space(3)
          Repeater {
            model: root.hw ? root.hw.cores : []

            Item {
              required property var modelData
              width: Style.space(9)
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

      // ================================================== HISTORY
      Column {
        width: parent.width
        spacing: Style.space(10)

        Text {
          text: "HISTORY"
          color: root.dim
          font.family: root.fam
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
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

      // ================================================== MEMORY
      Column {
        width: parent.width
        spacing: Style.space(6)

        Text {
          text: "MEMORY"
          color: root.dim
          font.family: root.fam
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
        }

        Item {
          width: parent.width
          height: memLabel.implicitHeight

          Text {
            id: memLabel
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
        }
      }

      // ================================================== DISK
      Column {
        width: parent.width
        spacing: Style.space(6)

        Text {
          text: "DISK"
          color: root.dim
          font.family: root.fam
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
        }

        Text {
          text: root.hw ? ("Root  " + (root.hw.diskTotalBytes > 0 ? (root.hw.diskUsedBytes / 1073741824).toFixed(0) + " / " + (root.hw.diskTotalBytes / 1073741824).toFixed(0) + " GB (" + Math.round(root.hw.diskPercent) + "%)" : "—")) : ""
          color: root.fg
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }

        Rectangle {
          width: parent.width
          height: Style.space(6)
          radius: Style.cornerRadius > 0 ? height / 2 : 0
          color: root.track
          visible: root.hw && root.hw.diskTotalBytes > 0

          Rectangle {
            width: Math.round(parent.width * (root.hw && root.hw.diskTotalBytes > 0 ? root.hw.diskUsedBytes / root.hw.diskTotalBytes : 0))
            height: parent.height
            radius: parent.radius
            color: Style.selectedStateColor(root.fg, Color.accent)

            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
          }
        }

        Text {
          text: root.hw ? ("Read  " + root.hw.speed(root.hw.diskReadSpeed) + "   ·   Write  " + root.hw.speed(root.hw.diskWriteSpeed) +
            (root.hw.nvmeTempC > 0 ? "   ·   " + Math.round(root.hw.nvmeTempC) + "\u00B0C" : "")) : ""
          color: root.dim
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }
      }

      // ================================================== NETWORK
      Column {
        width: parent.width
        spacing: Style.space(6)

        Text {
          text: "NETWORK"
          color: root.dim
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
          visible: root.hw && root.hw.netIface !== ""
          text: root.hw ? ("Total since boot   \u2193" + (root.hw.netRxTotal / 1073741824).toFixed(1) + " GB   \u2191" + (root.hw.netTxTotal / 1073741824).toFixed(1) + " GB" +
            (root.localIp !== "" ? "   ·   " + root.localIp : "")) : ""
          color: root.dim
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }
      }

      // ================================================== BATTERY
      Column {
        width: parent.width
        spacing: Style.space(6)
        visible: root.hw && root.hw.batteryPresent

        Text {
          text: "BATTERY"
          color: root.dim
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

        Repeater {
          model: [
            { key: "showCpu", label: "CPU" },
            { key: "showMem", label: "Memory" },
            { key: "showNet", label: "Network" },
            { key: "showBattery", label: "Battery" },
            { key: "notifications", label: "Alert notifications" }
          ]

          delegate: Item {
            width: parent.width
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
              checked: root.hw ? root.hw.setting(modelData.key, modelData.key === "notifications" ? false : true) : false
              foreground: root.fg
              onToggled: {
                var patch = {}
                patch[modelData.key] = checked
                root.persistSettings(patch)
              }
            }
          }
        }
      }
    }
  }
}
