import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

FocusScope {
  id: root
  property var snapshot: ({})
  property bool active: false
  property bool busy: false
  property bool failed: false
  property string message: ""
  property string output: ""
  property color ink: "#eeeeee"
  property color surface: "#171717"
  property color accent: "#a970ff"
  property string fontFamily: "sans-serif"
  property int fontSize: 13
  property int page: 0
  property bool submitted: false
  property bool initiallyInstalled: false
  readonly property bool succeeded: submitted && !busy && !failed && snapshot.installed === true
  signal requested(string action, bool confirmed)
  signal dismissRequested()

  function semanticColor(category, fallback) {
    var rows = root.snapshot.legend || [];
    for (var index = 0; index < rows.length; ++index) {
      var row = rows[index];
      if (row && row.category === category && /^#[0-9a-fA-F]{6}$/.test(row.color || "")) return row.color;
    }
    return fallback;
  }

  function reset() {
    root.page = 0;
    root.submitted = false;
    root.initiallyInstalled = root.snapshot.installed === true;
  }

  function goBack() {
    if (root.busy) return;
    if (root.page > 0 && !root.succeeded) root.page -= 1;
    else root.dismissRequested();
  }

  function submit() {
    if (root.busy) return;
    root.submitted = true;
    root.page = 2;
    root.requested("setup", true);
  }

  onActiveChanged: if (active) reset()
  onSnapshotChanged: {
    // ControlView can activate the wizard in the same update that replaces an
    // installed snapshot with the first-install snapshot. Keep the welcome
    // copy in sync until the user actually submits the setup.
    if (active && !submitted && page === 0) {
      initiallyInstalled = snapshot.installed === true;
    }
  }
  onSucceededChanged: if (succeeded) page = 2

  Keys.onEscapePressed: function(event) {
    root.goBack();
    event.accepted = true;
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 14

    RowLayout {
      Layout.fillWidth: true
      spacing: 12

      BrandMark {
        Layout.preferredWidth: 54
        Layout.preferredHeight: 54
        foreground: root.ink
        surface: root.surface
        violet: root.accent
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text {
          Layout.fillWidth: true
          text: root.initiallyInstalled ? "UPDATE COMMAND CHROMA" : "WELCOME TO COMMAND CHROMA"
          textFormat: Text.PlainText
          color: root.ink
          font { family: root.fontFamily; pixelSize: root.fontSize + 6; bold: true }
          wrapMode: Text.WordWrap
        }
        Text {
          Layout.fillWidth: true
          text: "A guided setup for semantic Bash command colors."
          textFormat: Text.PlainText
          color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.72)
          font { family: root.fontFamily; pixelSize: root.fontSize }
          wrapMode: Text.WordWrap
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 6
      Repeater {
        model: ["WELCOME", "REVIEW", "FINISH"]
        Rectangle {
          required property string modelData
          required property int index
          Layout.fillWidth: true
          implicitHeight: 28
          radius: 14
          color: index <= root.page
                 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, index === root.page ? 0.28 : 0.14)
                 : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.05)
          border.width: index === root.page ? 1 : 0
          border.color: root.accent
          Text {
            anchors.centerIn: parent
            text: (index + 1) + "  " + modelData
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: Math.max(9, root.fontSize - 2); bold: index === root.page }
          }
        }
      }
    }

    StackLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      currentIndex: root.page

      ScrollView {
        id: welcomeScroll
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ColumnLayout {
          width: welcomeScroll.availableWidth
          spacing: 14
          Item { Layout.fillWidth: true; implicitHeight: 2 }
          Text {
            Layout.fillWidth: true
            text: root.initiallyInstalled ? "Refresh the engine behind your prompt." : "See what a command does before you run it."
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize + 4; bold: true }
            wrapMode: Text.WordWrap
          }
          Text {
            Layout.fillWidth: true
            text: "Chroma follows your Omarchy theme and keeps every managed foreground at a readable contrast. Your command is never executed by the color preview."
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize }
            wrapMode: Text.WordWrap
          }
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: previewColumn.implicitHeight + 26
            radius: 8
            color: /^#[0-9a-fA-F]{6}$/.test(root.snapshot.palette && root.snapshot.palette.background || "")
                   ? root.snapshot.palette.background : "#101016"
            border.width: 1
            border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.16)
            ColumnLayout {
              id: previewColumn
              anchors { left: parent.left; right: parent.right; top: parent.top; margins: 13 }
              spacing: 9
              Text {
                Layout.fillWidth: true
                text: "$ sudo pacman -Syu"
                textFormat: Text.PlainText
                color: root.semanticColor("install", "#ffd166")
                font { family: "monospace"; pixelSize: root.fontSize; bold: true }
              }
              Text {
                Layout.fillWidth: true
                text: "$ git push --force-with-lease"
                textFormat: Text.PlainText
                color: root.semanticColor("danger", "#ff5d73")
                font { family: "monospace"; pixelSize: root.fontSize; bold: true; underline: true }
              }
              Text {
                Layout.fillWidth: true
                text: "$ curl https://example.com"
                textFormat: Text.PlainText
                color: root.semanticColor("network", "#52d6ff")
                font { family: "monospace"; pixelSize: root.fontSize; bold: true }
              }
            }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
              model: ["THEME-AWARE", "5.5:1 TARGET", "NO TELEMETRY"]
              Rectangle {
                required property string modelData
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 5
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                Text {
                  anchors.centerIn: parent
                  width: parent.width - 10
                  horizontalAlignment: Text.AlignHCenter
                  text: modelData
                  textFormat: Text.PlainText
                  color: root.ink
                  font { family: root.fontFamily; pixelSize: Math.max(9, root.fontSize - 2); bold: true }
                  wrapMode: Text.WordWrap
                }
              }
            }
          }
        }
      }

      ScrollView {
        id: reviewScroll
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ColumnLayout {
          width: reviewScroll.availableWidth
          spacing: 10
          Text {
            Layout.fillWidth: true
            text: "Review the changes"
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize + 4; bold: true }
          }
          Text {
            Layout.fillWidth: true
            text: "Nothing below happens until you press the final install button."
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize }
            wrapMode: Text.WordWrap
          }
          Repeater {
            model: [
              {number: "01", title: "Install the Bash engine", detail: root.snapshot.installPath || "~/.local/share/omarchy-chroma"},
              {number: "02", title: "Back up and add one loader", detail: root.snapshot.bashrc || "~/.bashrc"},
              {number: "03", title: "Provide the highlighting engine", detail: root.snapshot.blePath ? "Use existing ble.sh" : "Download one pinned, checksum-verified ble.sh build if missing"}
            ]
            Rectangle {
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: reviewRow.implicitHeight + 22
              radius: 7
              color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.055)
              RowLayout {
                id: reviewRow
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 11 }
                spacing: 11
                Rectangle {
                  Layout.preferredWidth: 34
                  Layout.preferredHeight: 34
                  radius: 17
                  color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                  Text {
                    anchors.centerIn: parent
                    text: modelData.number
                    color: root.ink
                    font { family: "monospace"; pixelSize: root.fontSize - 1; bold: true }
                  }
                }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 3
                  Text {
                    Layout.fillWidth: true
                    text: modelData.title
                    textFormat: Text.PlainText
                    color: root.ink
                    font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                    wrapMode: Text.WordWrap
                  }
                  Text {
                    Layout.fillWidth: true
                    text: modelData.detail
                    textFormat: Text.PlainText
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.72)
                    font { family: "monospace"; pixelSize: root.fontSize - 1 }
                    wrapMode: Text.WrapAnywhere
                  }
                }
              }
            }
          }
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: safetyText.implicitHeight + 22
            radius: 7
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.09)
            border.width: 1
            border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.16)
            Text {
              id: safetyText
              anchors { left: parent.left; right: parent.right; top: parent.top; margins: 11 }
              text: "No sudo · no system packages · no command-history access · no telemetry\nExisting Chroma settings and symlinked .bashrc files are preserved."
              textFormat: Text.PlainText
              color: root.ink
              font { family: root.fontFamily; pixelSize: root.fontSize }
              wrapMode: Text.WordWrap
            }
          }
          Text {
            Layout.fillWidth: true
            visible: root.snapshot.malformed === true
            text: "Attention: the existing Chroma block in .bashrc is malformed. Setup will refuse to overwrite it and explain how to recover."
            textFormat: Text.PlainText
            color: root.semanticColor("danger", "#ff5d73")
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
            wrapMode: Text.WordWrap
          }
        }
      }

      ScrollView {
        id: resultScroll
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ColumnLayout {
          width: resultScroll.availableWidth
          spacing: 13
          Item { Layout.fillWidth: true; implicitHeight: 6 }
          BrandMark {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 82
            Layout.preferredHeight: 82
            foreground: root.ink
            surface: root.surface
            violet: root.accent
          }
          BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            visible: root.busy
            running: root.busy
            palette.highlight: root.accent
          }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.busy ? "INSTALLING…"
                  : (root.succeeded ? "CHROMA IS READY" : "SETUP NEEDS ATTENTION")
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize + 5; bold: true }
            wrapMode: Text.WordWrap
          }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.busy
                  ? "Preparing the Bash engine and verifying its dependencies. Keep this panel open."
                  : (root.succeeded
                     ? "Open a new Bash terminal so the integration can load. The dashboard remains available from the Chroma icon."
                     : (root.message || "The setup did not complete. Nothing hidden will be retried automatically."))
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize }
            wrapMode: Text.WordWrap
          }
          Rectangle {
            Layout.fillWidth: true
            visible: root.succeeded
            implicitHeight: nextColumn.implicitHeight + 22
            radius: 7
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
            ColumnLayout {
              id: nextColumn
              anchors { left: parent.left; right: parent.right; top: parent.top; margins: 11 }
              spacing: 5
              Text {
                Layout.fillWidth: true
                text: "NEXT STEP"
                textFormat: Text.PlainText
                color: root.ink
                font { family: root.fontFamily; pixelSize: root.fontSize - 1; bold: true }
              }
              Text {
                Layout.fillWidth: true
                text: "Open a new terminal and run  chroma doctor"
                textFormat: Text.PlainText
                color: root.semanticColor("inspect", root.ink)
                font { family: "monospace"; pixelSize: root.fontSize; bold: true }
                wrapMode: Text.WordWrap
              }
            }
          }
          TextArea {
            Layout.fillWidth: true
            visible: !root.busy && root.output.length > 0
            text: root.output
            textFormat: TextEdit.PlainText
            readOnly: true
            selectByMouse: true
            color: root.ink
            font { family: "monospace"; pixelSize: root.fontSize - 1 }
            wrapMode: TextEdit.WrapAnywhere
            background: Rectangle { color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.055); radius: 6 }
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      visible: !root.busy
      spacing: 8
      ActionButton {
        objectName: "setup-back"
        Layout.fillWidth: true
        visible: root.page === 1 || (root.page === 2 && !root.succeeded)
        text: root.page === 1 ? "Back" : "Review again"
        ink: root.ink; surface: root.surface; accent: root.accent
        font { family: root.fontFamily; pixelSize: root.fontSize }
        onClicked: root.goBack()
      }
      ActionButton {
        objectName: "setup-next"
        Layout.fillWidth: true
        visible: root.page === 0
        text: "Review setup"
        ink: root.ink; surface: root.surface; accent: root.accent
        emphasized: true
        font { family: root.fontFamily; pixelSize: root.fontSize }
        onClicked: root.page = 1
      }
      ActionButton {
        objectName: "setup-install"
        Layout.fillWidth: true
        visible: root.page === 1
        text: root.initiallyInstalled ? "Install update" : "Install Command Chroma"
        ink: root.ink; surface: root.surface; accent: root.accent
        emphasized: true
        font { family: root.fontFamily; pixelSize: root.fontSize }
        onClicked: root.submit()
      }
      ActionButton {
        objectName: "setup-retry"
        Layout.fillWidth: true
        visible: root.page === 2 && !root.succeeded
        text: "Retry"
        ink: root.ink; surface: root.surface; accent: root.accent
        emphasized: true
        font { family: root.fontFamily; pixelSize: root.fontSize }
        onClicked: root.submit()
      }
      ActionButton {
        objectName: "setup-done"
        Layout.fillWidth: true
        visible: root.page === 2 && root.succeeded
        text: "Open dashboard"
        ink: root.ink; surface: root.surface; accent: root.accent
        emphasized: true
        font { family: root.fontFamily; pixelSize: root.fontSize }
        onClicked: root.dismissRequested()
      }
    }
  }
}
