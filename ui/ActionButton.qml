import QtQuick
import QtQuick.Controls

Button {
  id: root
  property color ink: "#eeeeee"
  property color surface: "#171717"
  property color accent: "#a970ff"
  property color accentHover: "#b88aff"
  property color accentPressed: "#8b55e6"
  property color error: "#f87171"
  property color errorHover: "#ff9494"
  property color disabledOpacity: 0.38
  property bool emphasized: false
  property bool destructive: false
  property int minTouchTarget: 44
  font.pixelSize: 13
  padding: 12
  hoverEnabled: true
  activeFocusOnTab: true
  focusPolicy: Qt.StrongFocus
  // Ensure minimum touch target
  implicitHeight: Math.max(minTouchTarget, contentItem.implicitHeight + topPadding + bottomPadding)
  implicitWidth: Math.max(minTouchTarget, contentItem.implicitWidth + leftPadding + rightPadding)

  contentItem: Text {
    text: root.text
    textFormat: Text.PlainText
    font: root.font
    color: root.enabled
      ? (root.destructive ? root.error : root.ink)
      : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, root.disabledOpacity)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    wrapMode: Text.WordWrap
    elide: Text.ElideRight
  }

  background: Rectangle {
    id: bg
    radius: 6
    // Layered states: pressed > focused > hovered > default
    color: root.down
      ? (root.destructive ? Qt.rgba(root.error.r, root.error.g, root.error.b, 0.24) : Qt.rgba(root.accentPressed.r, root.accentPressed.g, root.accentPressed.b, 0.24))
      : (root.activeFocus
          ? (root.emphasized || root.destructive
              ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
              : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.12))
          : (root.hovered && root.enabled
              ? (root.destructive ? Qt.rgba(root.error.r, root.error.g, root.error.b, 0.12) : Qt.rgba(root.accentHover.r, root.accentHover.g, root.accentHover.b, 0.12))
              : root.surface))
    border.width: root.activeFocus ? 2 : (root.emphasized || root.destructive ? 1.5 : 1)
    border.color: root.activeFocus
      ? root.focusRing
      : (root.emphasized
          ? root.accent
          : (root.destructive ? root.error : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.20)))

    // Subtle scale on press for tactile feedback
    scale: root.down ? 0.98 : 1.0
    transformOrigin: Item.Center
    Behavior on scale {
      PropertyAnimation { duration: 100; easing.type: Easing.OutCubic }
    }
    Behavior on color {
      PropertyAnimation { duration: 120; easing.type: Easing.OutCubic }
    }
    Behavior on border.color {
      PropertyAnimation { duration: 120; easing.type: Easing.OutCubic }
    }
  }

  // Accessible focus indicator
  Accessible.role: Accessible.Button
  Accessible.name: root.text
  Accessible.description: root.enabled ? "" : "Disabled"
}