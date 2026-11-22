import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

import "ui" as ChromaUi

ShellRoot {
  id: root

  Backend { id: backend }

  FloatingWindow {
    id: window
    title: "Omarchy Chroma Studio"
    implicitWidth: 980
    implicitHeight: 820
    visible: true
    color: "#0b1020"

    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: "#0b1020" }
        GradientStop { position: 1.0; color: "#111827" }
      }
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 20
      spacing: 16

      RowLayout {
        Layout.fillWidth: true
        spacing: 16
        Rectangle {
          width: 44; height: 44; radius: 12
          gradient: Gradient {
            GradientStop { position: 0.0; color: "#38bdf8" }
            GradientStop { position: 1.0; color: "#a78bfa" }
          }
          Text {
            anchors.centerIn: parent
            text: "C"
            color: "#0b1020"
            font.pixelSize: 22
            font.bold: true
          }
        }
        ColumnLayout {
          spacing: 2
          Text {
            text: "Omarchy Chroma Studio"
            color: "#f8fafc"
            font.pixelSize: 24
            font.bold: true
          }
          Text {
            text: "The styling centre for your entire Omarchy system"
            color: "#94a3b8"
            font.pixelSize: 13
          }
        }
        Item { Layout.fillWidth: true }
        Button {
          text: "Close"
          onClicked: Qt.quit()
          background: Rectangle { radius: 8; color: "#1f2937" }
          contentItem: Text { text: parent.text; color: "#e5e7eb"; horizontalAlignment: Text.AlignHCenter }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 16
        color: "#111827"
        border.color: "#1f2937"
        border.width: 1

        ChromaUi.ControlView {
          anchors.fill: parent
          anchors.margins: 16
          snapshot: backend.snapshot
          busy: backend.busy
          failed: backend.failed
          message: backend.message
          output: backend.output
          ink: "#e5e7eb"
          surface: "#1f2937"
          accent: "#a78bfa"
          fontFamily: "sans-serif"
          fontSize: 13
          onRequested: function(action, confirmed) {
            if (backend) backend.request(action, confirmed);
          }
          onCloseRequested: Qt.quit()
        }
      }
    }

    Component.onCompleted: backend.request("inspect", false)
  }
}