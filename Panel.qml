import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "ravattailor.sysmon"
  ipcTarget: "ravattailor.sysmon"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var hw: hostWidget
  readonly property var barIdentity: hostWidget || root

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string fam: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(fg, 1.5)
  readonly property color track: Qt.rgba(fg.r, fg.g, fg.b, 0.12)

  property real diskTotalBytes: 0
  property real diskUsedBytes: 0
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
    dfProc.running = true
    ipProc.running = true
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
    id: dfProc
    command: ["bash", "-c", "df -B1 --output=size,used / 2>/dev/null | tail -1"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var f = String(text).trim().split(/\s+/)
        if (f.length >= 2) {
          root.diskTotalBytes = Number(f[0])
          root.diskUsedBytes = Number(f[1])
        }
      }
    }
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
          text: root.hw ? ("Root  " + (root.diskTotalBytes > 0 ? (root.diskUsedBytes / 1073741824).toFixed(0) + " / " + (root.diskTotalBytes / 1073741824).toFixed(0) + " GB (" + Math.round(100 * root.diskUsedBytes / root.diskTotalBytes) + "%)" : "—")) : ""
          color: root.fg
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }

        Rectangle {
          width: parent.width
          height: Style.space(6)
          radius: Style.cornerRadius > 0 ? height / 2 : 0
          color: root.track
          visible: root.diskTotalBytes > 0

          Rectangle {
            width: Math.round(parent.width * (root.diskTotalBytes > 0 ? root.diskUsedBytes / root.diskTotalBytes : 0))
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
    }
  }
}
