import QtQuick
import Quickshell.Io
import QtQuick.Controls
import QtQuick.Layouts
import "../Model.js" as Model

FocusScope {
  id: root
  property var snapshot: ({})
  property bool busy: false
  property bool failed: false
  property string message: ""
  property string output: ""
  property string aiTranscript: ""
  property bool aiBusy: false
  property string aiProposed: ""
  property int typingStep: 0
  property string aiHistoryFile: ""
  property color ink: "#eeeeee"
  property color surface: "#171717"
  property color accent: ink
  property string fontFamily: "sans-serif"
  property int fontSize: 13
  property string pendingAction: ""
  property bool showLegend: false
  readonly property var paletteInfo: snapshot.palette || ({})
  signal requested(string action, bool confirmed)
  signal closeRequested()

  function beginSetup() {
    if (root.busy || root.pendingAction) return;
    root.requested("installer", false);
  }

  function choose(action) {
    if (root.busy) return;
    if (action === "setup") { root.beginSetup(); return; }
    if (Model.needsConfirmation(action)) {
      root.pendingAction = action;
      Qt.callLater(function() { cancelButton.forceActiveFocus(); });
    } else {
      if (action === "legend") root.showLegend = true;
      root.requested(action, false);
    }
  }

  function sendAi(prompt) {
    if (root.aiBusy || !prompt || !prompt.trim()) return;
    root.aiTranscript += "You: " + prompt.trim() + "\n";
    root.aiBusy = true;
    aiProcess.command = ["python3", Qt.resolvedUrl("../scripts/chroma-ai-agent.py").toString().replace(/^file:\/\//, ""), "--once", prompt.trim()];
    aiProcess.running = true;
  }

  function confirmPending() {
    if (!root.pendingAction || root.busy) return;
    var action = root.pendingAction;
    root.pendingAction = "";
    root.requested(action, true);
  }

  Keys.onEscapePressed: function(event) {
    if (root.pendingAction) root.pendingAction = "";
    else root.closeRequested();
    event.accepted = true;
  }

  ScrollView {
    id: scroll
    anchors.fill: parent
    clip: true
    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    ColumnLayout {
      width: scroll.availableWidth
      spacing: 12

      Text {
        Layout.fillWidth: true
        text: "COMMAND CHROMA"
        textFormat: Text.PlainText
        color: root.ink
        font.family: root.fontFamily
        font.pixelSize: root.fontSize + 8
        font.bold: true
      }
      Text {
        Layout.fillWidth: true
        text: "Semantic command colors for your Omarchy Bash terminal."
        textFormat: Text.PlainText
        color: root.ink
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        wrapMode: Text.WordWrap
      }
      Text {
        Layout.fillWidth: true
        visible: root.snapshot.installed !== true || root.snapshot.updateAvailable === true
        text: "Setup runs in your terminal with the Chroma text animation. Review and confirm there; opening this panel never installs anything."
        textFormat: Text.PlainText
        color: root.ink
        font { family: root.fontFamily; pixelSize: root.fontSize }
        wrapMode: Text.WordWrap
      }
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: statusColumn.implicitHeight + 24
        radius: 5
        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
        ColumnLayout {
          id: statusColumn
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
          spacing: 6
          Text {
            Layout.fillWidth: true
            text: Model.statusLabel(root.snapshot)
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize + 1; bold: true }
            wrapMode: Text.WordWrap
          }
          Text {
            Layout.fillWidth: true
            text: "Theme: " + (root.paletteInfo.name || "not inspected")
                  + (root.paletteInfo.mode && root.paletteInfo.mode !== "unknown" ? " · " + root.paletteInfo.mode : "")
                  + "\nMeasured minimum: " + (root.paletteInfo.worst && root.paletteInfo.worst !== "unknown" ? root.paletteInfo.worst + ":1" : "unavailable")
                  + "  ·  Target: " + (root.paletteInfo.minimum || "—") + ":1"
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize }
            wrapMode: Text.WordWrap
          }
          Text {
            Layout.fillWidth: true
            text: "Contrast covers theme-managed foregrounds; custom styles are excluded."
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
            wrapMode: Text.WordWrap
          }
          Text {
            Layout.fillWidth: true
            text: "Plugin " + (root.snapshot.pluginVersion || "—") + " · Bash " + (root.snapshot.installedVersion || "not installed")
                  + (root.snapshot.updateAvailable ? " · Bash update available" : "")
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
            wrapMode: Text.WordWrap
          }
        }
      }

      Text {
        Layout.fillWidth: true
        visible: text.length > 0
        text: String(root.snapshot.paletteError || root.paletteInfo.warnings || "")
        textFormat: Text.PlainText
        color: root.ink
        font { family: root.fontFamily; pixelSize: root.fontSize }
        wrapMode: Text.WrapAnywhere
      }

      GridLayout {
        Layout.fillWidth: true
        columns: root.width >= 420 ? 3 : 2
        rowSpacing: 8
        columnSpacing: 8
        Repeater {
          model: [
            {action: "setup", label: "Set up in terminal"},
            {action: root.snapshot.paused ? "enable" : "disable", label: root.snapshot.paused ? "Enable" : "Disable"},
            {action: "reload", label: "Reload theme"},
            {action: "doctor", label: "Doctor"},
            {action: "legend", label: "Legend"},
            {action: "ai", label: "AI Stylist (terminal)"},
          ]
          ActionButton {
            required property var modelData
            objectName: "action-" + modelData.action
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            text: modelData.label
            ink: root.ink
            surface: root.surface
            accent: root.accent
            emphasized: modelData.action === "setup" && (root.snapshot.installed !== true || root.snapshot.updateAvailable === true)
            font { family: root.fontFamily; pixelSize: root.fontSize }
            enabled: !root.busy && !root.pendingAction && (root.snapshot.installed || ["setup", "legend", "inspect"].indexOf(modelData.action) >= 0)
            onClicked: {
              if (modelData.action === "setup") root.beginSetup();
              else root.choose(modelData.action);
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        visible: root.pendingAction.length > 0
        implicitHeight: confirmColumn.implicitHeight + 24
        radius: 5
        color: root.surface
        border { color: root.ink; width: 1 }
        ColumnLayout {
          id: confirmColumn
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
          spacing: 12
          Text {
            Layout.fillWidth: true
            text: Model.confirmation(root.pendingAction, root.snapshot)
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize }
            wrapMode: Text.Wrap
          }
          RowLayout {
            Layout.fillWidth: true
            ActionButton {
              id: cancelButton
              objectName: "cancel"
              Layout.fillWidth: true
              text: "Cancel"
              ink: root.ink; surface: root.surface; accent: root.accent
              font { family: root.fontFamily; pixelSize: root.fontSize }
              onClicked: root.pendingAction = ""
            }
            ActionButton {
              objectName: "confirm"
              Layout.fillWidth: true
              text: "Confirm"
              ink: root.ink; surface: root.surface; accent: root.accent
              font { family: root.fontFamily; pixelSize: root.fontSize }
              enabled: !root.busy
              emphasized: true
              onClicked: root.confirmPending()
            }
          }
        }
      }

      Text {
        Layout.fillWidth: true
        visible: root.message.length > 0
        text: (root.failed ? "Attention: " : "") + root.message
        textFormat: Text.PlainText
        color: root.ink
        font { family: root.fontFamily; pixelSize: root.fontSize; bold: root.failed }
        wrapMode: Text.WrapAnywhere
      }
      TextArea {
        Layout.fillWidth: true
        visible: root.output.length > 0
        text: root.output
        textFormat: TextEdit.PlainText
        readOnly: true
        selectByMouse: true
        color: root.ink
        font { family: "monospace"; pixelSize: root.fontSize - 1 }
        wrapMode: TextEdit.WrapAnywhere
        background: Rectangle { color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06) }
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: aiColumn.implicitHeight + 24
        radius: 5
        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
        ColumnLayout {
          id: aiColumn
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
          spacing: 8
          Text {
            Layout.fillWidth: true
            text: "AI STYLIST (local)"
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
          }
          ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            clip: true
            TextArea {
              text: root.aiTranscript
              textFormat: TextEdit.MarkdownText
              readOnly: true
              selectByMouse: true
              color: root.ink
              font { family: "monospace"; pixelSize: root.fontSize - 1 }
              wrapMode: TextEdit.WrapAnywhere
              background: Rectangle { color: "transparent" }
            }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            TextField {
              id: aiInput
              Layout.fillWidth: true
              placeholderText: "Ask the stylist…"
              color: root.ink
              font { family: root.fontFamily; pixelSize: root.fontSize }
              onAccepted: root.sendAi(text)
            }
            ActionButton {
              text: root.aiBusy ? "…" : "Send"
              ink: root.ink; surface: root.surface; accent: root.accent
              font { family: root.fontFamily; pixelSize: root.fontSize }
              enabled: !root.aiBusy
              onClicked: { root.sendAi(aiInput.text); aiInput.text = ""; }
            }
          }
          Text {
            Layout.fillWidth: true
            visible: root.aiBusy
            text: "Assistant is typing" + ".".repeat(root.typingStep + 1)
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize - 1; italic: true }
          }
          Rectangle {
            Layout.fillWidth: true
            visible: root.aiProposed.length > 0
            implicitHeight: propColumn.implicitHeight + 20
            radius: 5
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
            border { color: root.ink; width: 1 }
            ColumnLayout {
              id: propColumn
              anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
              spacing: 6
              Text {
                Layout.fillWidth: true
                text: "PROPOSED COMMANDS (dry run)"
                textFormat: Text.PlainText
                color: root.ink
                font { family: root.fontFamily; pixelSize: root.fontSize - 1; bold: true }
              }
              Text {
                Layout.fillWidth: true
                text: root.aiProposed
                textFormat: Text.PlainText
                color: root.ink
                font { family: "monospace"; pixelSize: root.fontSize - 1 }
                wrapMode: Text.WrapAnywhere
              }
              Repeater {
                model: root.aiProposed.split("\n").map(function(c){return c.trim();}).filter(function(c){return c.length>0;})
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 6
                  Text {
                    Layout.fillWidth: true
                    text: modelData
                    textFormat: Text.PlainText
                    color: root.ink
                    font { family: "monospace"; pixelSize: root.fontSize - 1 }
                    wrapMode: Text.WrapAnywhere
                  }
                  ActionButton {
                    text: "Apply"
                    ink: root.ink; surface: root.surface; accent: root.accent
                    font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
                    enabled: !root.aiBusy
                    onClicked: {
                      root.aiTranscript += "Applying: " + modelData + "\n";
                      aiApplyProc.command = ["bash", "-c", modelData];
                      aiApplyProc.running = true;
                    }
                  }
                }
              }
            }
          }
          ActionButton {
            Layout.fillWidth: true
            text: "Clear chat"
            ink: root.ink; surface: root.surface; accent: root.accent
            font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
            enabled: !root.aiBusy
            onClicked: { root.aiTranscript = ""; aiClearProc.running = true; }
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        visible: root.showLegend
        spacing: 8
        Text {
          Layout.fillWidth: true
          text: "COLOR LEGEND · examples are never executed"
          textFormat: Text.PlainText
          color: root.ink
          font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
          wrapMode: Text.WordWrap
        }
        Repeater {
          model: root.snapshot.legend || []
          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: legendColumn.implicitHeight + 16
            radius: 3
            color: /^#[0-9a-fA-F]{6}$/.test(root.paletteInfo.background || "") ? root.paletteInfo.background : root.surface
            ColumnLayout {
              id: legendColumn
              anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
              Text {
                Layout.fillWidth: true
                text: String(modelData.category || "other").toUpperCase() + "  ·  " + String(modelData.example || "")
                textFormat: Text.PlainText
                color: modelData.color || root.ink
                font { family: "monospace"; pixelSize: root.fontSize; bold: true; underline: String(modelData.style || "").indexOf("underline") >= 0 }
                wrapMode: Text.WordWrap
              }
              Text {
                Layout.fillWidth: true
                text: (modelData.style || "plain")
                      + (modelData.ratio && modelData.ratio !== "unknown"
                         ? " · " + modelData.ratio + ":1"
                         : " · custom/indexed style; no measured preview")
                textFormat: Text.PlainText
                color: modelData.color || root.ink
                font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
                wrapMode: Text.WrapAnywhere
              }
            }
          }
        }
      }

      Text {
        Layout.fillWidth: true
        text: "Enable/disable applies to NEW terminals. Theme reload reaches already loaded Chroma shells at their next prompt. Code/config changes need a new terminal.\n\nThis widget and the Bash add-on have separate lifetimes. Remove the Bash integration below before removing the widget if you want both gone."
        textFormat: Text.PlainText
        color: root.ink
        font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
        wrapMode: Text.WordWrap
      }
      ActionButton {
        Layout.fillWidth: true
        text: "Remove Bash integration…"
        ink: root.ink; surface: root.surface; accent: root.accent
        font { family: root.fontFamily; pixelSize: root.fontSize }
        enabled: root.snapshot.installed === true && !root.busy && !root.pendingAction
        onClicked: root.choose("uninstall")
      }
    }
  }

  Process {
    id: aiProcess
    stdout: StdioCollector { id: aiStdout; waitForEnd: true }
    stderr: StdioCollector { id: aiStderr; waitForEnd: true }
    onExited: function(code) {
      root.aiBusy = false;
      var text = aiStdout.text.trim();
      if (!text) text = aiStderr.text.trim();
      if (!text) text = "(no response)";
      root.aiTranscript += "Assistant: " + text + "\n\n";
      // Parse proposed commands (lines after "COMMANDS:" prefixed with "- ")
      var cmds = [];
      var inC = false;
      var lines = text.split("\n");
      for (var i = 0; i < lines.length; i++) {
        var ln = lines[i].trim();
        if (ln.toUpperCase().indexOf("COMMANDS:") === 0) { inC = true; continue; }
        if (inC) {
          if (!ln) { inC = false; continue; }
          if (ln.indexOf("- ") === 0) cmds.push(ln.substring(2).trim());
          else inC = false;
        }
      }
      root.aiProposed = cmds.join("\n");
    }
  }

  Process {
    id: aiHistoryLoader
    command: ["bash", "-c", "cat ~/.local/state/omarchy-chroma/ai-chat.log 2>/dev/null || true"]
    stdout: StdioCollector { id: aiHistoryStdout; waitForEnd: true }
    onExited: function(code) { root.aiTranscript = aiHistoryStdout.text; }
  }
  Component.onCompleted: aiHistoryLoader.running = true

  Process {
    id: aiClearProc
    command: ["bash", "-c", ": > ~/.local/state/omarchy-chroma/ai-chat.log"]
    running: false
  }

  Process {
    id: aiApplyProc
    stdout: StdioCollector { id: aiApplyStdout; waitForEnd: true }
    stderr: StdioCollector { id: aiApplyStderr; waitForEnd: true }
    onExited: function(code) {
      var t = aiApplyStdout.text.trim();
      if (!t) t = aiApplyStderr.text.trim();
      if (!t) t = "(done)";
      root.aiTranscript += "Apply result: " + t + "\n\n";
      root.aiProposed = "";
    }
  }
  Timer {
    id: typingTimer
    interval: 400
    repeat: true
    running: root.aiBusy
    onTriggered: root.typingStep = (root.typingStep + 1) % 4
  }
}
