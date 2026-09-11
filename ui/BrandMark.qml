import QtQuick

Item {
  id: root
  property color foreground: "#f8f7ff"
  property color surface: "#17131f"
  property color violet: "#a970ff"
  property color pink: "#ff5da2"
  property color cyan: "#52d6ff"

  implicitWidth: 72
  implicitHeight: 72

  Rectangle {
    anchors.fill: parent
    radius: Math.max(4, width * 0.26)
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: root.pink }
      GradientStop { position: 0.52; color: root.violet }
      GradientStop { position: 1.0; color: root.cyan }
    }
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: Math.max(2, Math.round(parent.width * 0.10))
    radius: Math.max(3, width * 0.22)
    color: root.surface
    border.width: Math.max(1, Math.round(parent.width * 0.025))
    border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)

    Text {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: -Math.max(0, Math.round(parent.height * 0.025))
      text: ">_"
      textFormat: Text.PlainText
      color: root.foreground
      font.family: "monospace"
      font.pixelSize: Math.max(7, Math.round(parent.height * 0.42))
      font.bold: true
    }
  }
}
