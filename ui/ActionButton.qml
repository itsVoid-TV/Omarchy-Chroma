import QtQuick
import QtQuick.Controls

Button {
  id: root
  property color ink: "#eeeeee"
  property color surface: "#171717"
  property color accent: ink
  property bool emphasized: false
  font.pixelSize: 13
  padding: 12
  hoverEnabled: true
  activeFocusOnTab: true
  implicitHeight: Math.max(42, contentItem.implicitHeight + topPadding + bottomPadding)
  contentItem: Text {
    text: root.text
    textFormat: Text.PlainText
    font: root.font
    color: root.enabled ? root.ink : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    wrapMode: Text.WordWrap
  }
  background: Rectangle {
    radius: 5
    color: root.down ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
                    : (root.hovered || root.activeFocus ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10) : root.surface)
    border.width: root.activeFocus ? 2 : 1
    border.color: root.emphasized || root.activeFocus ? root.accent : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
  }
}
