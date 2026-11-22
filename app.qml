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
        GradientStop { position: 0.0; color: "#1a1033" }
        GradientStop { position: 1.0; color: "#0f172a" }
      }
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 20
      spacing: 16

      RowLayout {
        Layout.fillWidth: true
        spacing: 20
        ColumnLayout {
          spacing: 4
          Text {
            text: "Omarchy Chroma Studio"
            color: "#f8fafc"
            font.pixelSize: 30
            font.bold: true
          }
          Text {
            text: "Your styling centre for the entire Omarchy system"
            color: "#c4b5fd"
            font.pixelSize: 14
          }
          Text {
            text: "Themes · Plugins · .config · Lessons · Local AI Stylist"
            color: "#94a3b8"
            font.pixelSize: 12
          }
        }
        Item { Layout.fillWidth: true }
        Rectangle {
          width: 72; height: 72; radius: 36
          gradient: Gradient {
            GradientStop { position: 0.0; color: "#7c3aed" }
            GradientStop { position: 1.0; color: "#38bdf8" }
          }
          Text {
            anchors.centerIn: parent
            text: "C"
            color: "#ffffff"
            font.pixelSize: 34
            font.bold: true
          }
        }
        Button {
          text: "Close"
          onClicked: Qt.quit()
          background: Rectangle { radius: 10; color: "#7c3aed" }
          contentItem: Text { text: parent.text; color: "#ffffff"; horizontalAlignment: Text.AlignHCenter; font.bold: true }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 20
        color: "#1e1b2e"
        border.color: "#4c1d95"
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