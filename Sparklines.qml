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

  implicitHeight: col.implicitHeight
  implicitWidth: col.implicitWidth

  Column {
    id: col
    width: parent.width
    spacing: Style.space(10)

    // ---- CPU
    Column {
      width: parent.width
      spacing: Style.space(4)
      visible: root.hw ? root.hw.showCpu : true

      Row {
        width: parent.width

        Text {
          text: "CPU"
          color: root.dimCol
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }

        Text {
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
      width: parent.width
      spacing: Style.space(4)
      visible: root.hw ? root.hw.showMem : true

      Row {
        width: parent.width

        Text {
          text: "Memory"
          color: root.dimCol
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }

        Text {
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
      width: parent.width
      spacing: Style.space(4)
      visible: root.hw ? root.hw.showNet : true

      Row {
        width: parent.width

        Text {
          text: "Network"
          color: root.dimCol
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }

        Text {
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
      width: parent.width
      spacing: Style.space(4)
      visible: root.hw ? root.hw.showBattery && root.hw.batteryPresent : false

      Row {
        width: parent.width

        Text {
          text: "Battery"
          color: root.dimCol
          font.family: root.fam
          font.pixelSize: Style.font.bodySmall
        }

        Text {
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
}
