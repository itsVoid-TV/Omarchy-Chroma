import QtQuick
import QtQuick.Controls
import Quickshell

import "ui" as ChromaUi

ShellRoot {
  id: root

  Backend { id: backend }

  FloatingWindow {
    id: window
    title: "Omarchy Chroma Studio"
    implicitWidth: 920
    implicitHeight: 760
    visible: true
    color: "#171717"

    ChromaUi.ControlView {
      anchors.fill: parent
      anchors.margins: 16
      snapshot: backend.snapshot
      busy: backend.busy
      failed: backend.failed
      message: backend.message
      output: backend.output
      ink: "#e5e7eb"
      surface: "#23232a"
      accent: "#a78bfa"
      fontFamily: "sans-serif"
      fontSize: 13
      onRequested: function(action, confirmed) {
        if (backend) backend.request(action, confirmed);
      }
      onCloseRequested: Qt.quit()
    }

    Component.onCompleted: backend.request("inspect", false)
  }
}