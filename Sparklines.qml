import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property var hw: null
  property bool opened: false
  property color fg: Color.foreground
  property string fam: Style.font.family

  readonly property color dimCol: Qt.darker(fg, 1.5)
  readonly property color lineColor: Style.selectedStateColor(fg, Color.accent)
  readonly property color fillColor: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
  readonly property int rev: hw ? hw.historyVersion : 0

  function repaintAll() {
    cpuPlot.requestPaint()
    memPlot.requestPaint()
    netPlot.requestPaint()
    batPlot.requestPaint()
  }

  onRevChanged: repaintAll()
  onOpenedChanged: repaintAll()
  onFgChanged: repaintAll()
  Component.onCompleted: repaintAll()

  implicitHeight: wrap.implicitHeight
  implicitWidth: wrap.implicitWidth

  Column {
    id: wrap
    width: parent.width
    spacing: Style.space(4)

  Grid {
    id: col
    columns: 2
    width: parent.width
    columnSpacing: Style.space(14)
    rowSpacing: Style.space(8)

    // ---- CPU
    Column {
      width: (col.width - Style.space(14)) / 2
      spacing: Style.space(4)
      visible: root.hw ? root.hw.showCpu : true

      Item {
        width: parent.width
        height: Math.max(cpuTitle.implicitHeight, cpuVal.implicitHeight)

        Text {
          id: cpuTitle
          anchors.left: parent.left
          text: "CPU"
          color: root.dimCol
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          id: cpuVal
          anchors.right: parent.right
          text: root.hw ? root.hw.cpuPercent + "%" : "—"
          color: root.fg
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }
      }

      Canvas {
        id: cpuPlot
        width: parent.width
        height: Style.space(34)
        antialiasing: true

        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          var data = root.hw ? root.hw.cpuHistory : []
          if (!data || data.length < 2) return
          var n = data.length
          ctx.beginPath()
          for (var j = 0; j < n; j++) {
            var x = width * j / (n - 1)
            var y = height - 2 - (height - 4) * Math.min(1, data[j] / 100)
            if (j === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
          }
          ctx.strokeStyle = root.lineColor
          ctx.lineWidth = 1.5
          ctx.stroke()
          ctx.lineTo(width, height)
          ctx.lineTo(0, height)
          ctx.closePath()
          ctx.fillStyle = root.fillColor
          ctx.fill()
        }
        onWidthChanged: requestPaint()
      }
    }

    // ---- Memory
    Column {
      width: (col.width - Style.space(14)) / 2
      spacing: Style.space(4)
      visible: root.hw ? root.hw.showMem : true

      Item {
        width: parent.width
        height: Math.max(memTitle.implicitHeight, memVal.implicitHeight)

        Text {
          id: memTitle
          anchors.left: parent.left
          text: "Memory"
          color: root.dimCol
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          id: memVal
          anchors.right: parent.right
          text: root.hw ? Math.round(root.hw.memPercent) + "%" : "—"
          color: root.fg
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }
      }

      Canvas {
        id: memPlot
        width: parent.width
        height: Style.space(34)
        antialiasing: true

        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          var data = root.hw ? root.hw.memHistory : []
          if (!data || data.length < 2) return
          var n = data.length
          ctx.beginPath()
          for (var j = 0; j < n; j++) {
            var x = width * j / (n - 1)
            var y = height - 2 - (height - 4) * Math.min(1, data[j] / 100)
            if (j === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
          }
          ctx.strokeStyle = root.lineColor
          ctx.lineWidth = 1.5
          ctx.stroke()
          ctx.lineTo(width, height)
          ctx.lineTo(0, height)
          ctx.closePath()
          ctx.fillStyle = root.fillColor
          ctx.fill()
        }
        onWidthChanged: requestPaint()
      }
    }

    // ---- Network
    Column {
      width: (col.width - Style.space(14)) / 2
      spacing: Style.space(4)
      visible: root.hw ? root.hw.showNet : true

      Item {
        width: parent.width
        height: Math.max(netTitle.implicitHeight, netVal.implicitHeight)

        Text {
          id: netTitle
          anchors.left: parent.left
          text: "Network"
          color: root.dimCol
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          id: netVal
          anchors.right: parent.right
          text: root.hw && root.hw.netIface !== "" ? ("\u2193" + root.hw.speed(root.hw.netDown) + "  \u2191" + root.hw.speed(root.hw.netUp)) : "—"
          color: root.fg
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }
      }

      Canvas {
        id: netPlot
        width: parent.width
        height: Style.space(34)
        antialiasing: true

        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          var data = root.hw ? root.hw.netHistory : []
          if (!data || data.length < 2) return
          var max = 1
          for (var i = 0; i < data.length; i++)
            if (data[i] > max) max = data[i]
          max = max * 1.15
          var n = data.length
          ctx.beginPath()
          for (var j = 0; j < n; j++) {
            var x = width * j / (n - 1)
            var y = height - 2 - (height - 4) * Math.min(1, data[j] / max)
            if (j === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
          }
          ctx.strokeStyle = root.lineColor
          ctx.lineWidth = 1.5
          ctx.stroke()
          ctx.lineTo(width, height)
          ctx.lineTo(0, height)
          ctx.closePath()
          ctx.fillStyle = root.fillColor
          ctx.fill()
        }
        onWidthChanged: requestPaint()
      }
    }

    // ---- Battery
    Column {
      width: (col.width - Style.space(14)) / 2
      spacing: Style.space(4)
      visible: root.hw ? root.hw.showBattery && root.hw.batteryPresent : false

      Item {
        width: parent.width
        height: Math.max(batTitle.implicitHeight, batVal.implicitHeight)

        Text {
          id: batTitle
          anchors.left: parent.left
          text: "Battery"
          color: root.dimCol
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          id: batVal
          anchors.right: parent.right
          text: root.hw && root.hw.batteryPresent ? root.hw.batteryPercent + "%" : "—"
          color: root.fg
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }
      }

      Canvas {
        id: batPlot
        width: parent.width
        height: Style.space(34)
        antialiasing: true

        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          var data = root.hw ? root.hw.batHistory : []
          if (!data || data.length < 2) return
          var n = data.length
          ctx.beginPath()
          for (var j = 0; j < n; j++) {
            var x = width * j / (n - 1)
            var y = height - 2 - (height - 4) * Math.min(1, data[j] / 100)
            if (j === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
          }
          ctx.strokeStyle = root.lineColor
          ctx.lineWidth = 1.5
          ctx.stroke()
          ctx.lineTo(width, height)
          ctx.lineTo(0, height)
          ctx.closePath()
          ctx.fillStyle = root.fillColor
          ctx.fill()
        }
        onWidthChanged: requestPaint()
      }
    }
  }

    Item {
      width: parent.width
      height: agoLabel.implicitHeight

      Text {
        id: agoLabel
        anchors.left: parent.left
        text: {
          if (!root.hw || !root.hw.historySpan) return ""
          var s = String(root.hw.historySpan)
          if (s.indexOf("filling") === 0) return s
          return s.replace(/^last /, "") + " ago"
        }
        color: root.dimCol
        font.family: root.fam
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.right: parent.right
        text: root.hw && root.hw.cpuHistory && root.hw.cpuHistory.length >= 2 ? "now" : ""
        color: root.dimCol
        font.family: root.fam
        font.pixelSize: Style.font.caption
      }
    }
  }
}
