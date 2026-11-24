import QtQuick
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
  property color ink: "#eeeeee"
  property color surface: "#171717"
  property color accent: "#a970ff"
  property color accentHover: "#b88aff"
  property color accentPressed: "#8b55e6"
  property color success: "#4ade80"
  property color warning: "#fbbf24"
  property color error: "#f87171"
  property color border: Qt.rgba("#eeeeee", 0.12)
  property color focusRing: "#a970ff"
  property string fontFamily: "sans-serif"
  property int fontSize: 13
  property int spacingUnit: 8
  property string pendingAction: ""
  property bool showLegend: false
  property bool showLearn: false
  // BTW Hint system
  property var btwHint: null
  property bool showBtw: false
  readonly property var paletteInfo: snapshot.palette || ({})
  signal requested(string action, bool confirmed)
  signal closeRequested()

  onSnapshotChanged: {
    root.maybeShowBtwHint();
  }

  function maybeShowBtwHint() {
    if (root.showBtw || root.busy) return;
    var hints = [];
    var s = root.snapshot;
    if (!s) return;

    // Hint: Theme integration disabled but theme exists
    if (s.palette && s.palette.source === "omarchy" && s.configPath) {
      hints.push({
        title: "Theme integration is off",
        body: "Your Omarchy theme (" + (s.palette.name || "current") + ") isn't being used for highlighting. Enable it in config.bash.",
        lesson: "L02",
        action: "learn",
        key: "theme-integration-off"
      });
    }

    // Hint: Low contrast detected
    if (s.palette && s.palette.worst && s.palette.worst !== "unknown") {
      var worst = parseFloat(s.palette.worst);
      if (worst < 5.5) {
        hints.push({
          title: "Low contrast detected",
          body: "Worst contrast is " + s.palette.worst + ":1 (target 5.5:1). Chroma can auto-lift colors, or you can set custom styles.",
          lesson: "L02",
          action: "learn",
          key: "low-contrast"
        });
      }
    }

    // Hint: Bash not installed but widget enabled
    if (s.installed !== true && s.enabled === true) {
      hints.push({
        title: "Bash integration not installed",
        body: "The widget is active but semantic highlighting won't work until you run Set up in terminal.",
        lesson: "L01",
        action: "setup",
        key: "bash-not-installed"
      });
    }

    // Hint: Update available
    if (s.updateAvailable === true) {
      hints.push({
        title: "Bash update available",
        body: "Plugin updated but Bash code is outdated. Run Set up in terminal to get the latest highlighting rules.",
        lesson: "L01",
        action: "setup",
        key: "bash-update-available"
      });
    }

    // Hint: ble.sh missing
    if (s.blePath === "" || s.blePath === undefined) {
      hints.push({
        title: "ble.sh not found",
        body: "The line editor dependency is missing. Set up in terminal downloads a pinned, verified build automatically.",
        lesson: "L01",
        action: "setup",
        key: "blesh-missing"
      });
    }

    // Hint: Malformed .bashrc
    if (s.malformed === true) {
      hints.push({
        title: "Malformed .bashrc loader",
        body: "The Chroma block in .bashrc is corrupted. Run Set up in terminal to repair it safely.",
        lesson: "L01",
        action: "setup",
        key: "bashrc-malformed"
      });
    }

    // Hint: Disabled but installed
    if (s.paused === true && s.installed === true) {
      hints.push({
        title: "Chroma is paused",
        body: "Highlighting is disabled for new terminals. Click Enable to turn it back on.",
        lesson: "L01",
        action: "enable",
        key: "chroma-paused"
      });
    }

    if (hints.length === 0) return;

    // Pick one hint (could add randomization or priority later)
    var hint = hints[0];
    root.btwHint = hint;
    root.showBtw = true;
  }

  function dismissBtwHint() {
    root.showBtw = false;
    root.btwHint = null;
  }

  function doBtwAction() {
    if (!root.btwHint) return;
    var action = root.btwHint.action;
    root.dismissBtwHint();
    if (action === "setup") root.beginSetup();
    else if (action === "learn") { root.showLearn = true; root.showLegend = false; }
    else root.choose(action);
  }

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
      else if (action === "learn") root.showLearn = true;
      root.requested(action, false);
    }
  }

  function confirmPending() {
    if (!root.pendingAction || root.busy) return;
    var action = root.pendingAction;
    root.pendingAction = "";
    root.requested(action, true);
  }

  Keys.onEscapePressed: function(event) {
    if (root.pendingAction) root.pendingAction = "";
    else if (root.showLegend) root.showLegend = false;
    else if (root.showLearn) root.showLearn = false;
    else if (root.showBtw) root.dismissBtwHint();
    else root.closeRequested();
    event.accepted = true;
  }

  // Focus management for keyboard navigation
  property bool panelFocused: false
  onPanelFocusedChanged: {
    if (root.panelFocused && !root.busy) {
      // Set initial focus to first actionable element
      var firstAction = root.contentColumn.children.find(function(c) { return c.objectName && c.objectName.indexOf("action-") === 0; });
      if (firstAction) firstAction.forceActiveFocus();
    }
  }

  ScrollView {
    id: scroll
    anchors.fill: parent
    clip: true
    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AsNeeded

    ColumnLayout {
      id: contentColumn
      width: scroll.availableWidth
      spacing: 16
      Layout.leftMargin: 16
      Layout.rightMargin: 16
      Layout.topMargin: 16
      Layout.bottomMargin: 16

      // Header
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text {
          Layout.fillWidth: true
          text: "CHROMA STUDIO"
          textFormat: Text.PlainText
          color: root.ink
          font.family: root.fontFamily
          font.pixelSize: root.fontSize + 10
          font.bold: true
          font.weight: Font.ExtraBold
        }
        Text {
          Layout.fillWidth: true
          text: "Styling centre for Omarchy — highlighting, themes, lessons & AI"
          textFormat: Text.PlainText
          color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.65)
          font.family: root.fontFamily
          font.pixelSize: root.fontSize
          wrapMode: Text.WordWrap
        }
      }

      // Setup notice
      Text {
        Layout.fillWidth: true
        visible: root.snapshot.installed !== true || root.snapshot.updateAvailable === true
        text: "Setup runs in your terminal with the Chroma text animation. Review and confirm there; opening this panel never installs anything."
        textFormat: Text.PlainText
        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
        font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
        wrapMode: Text.WordWrap
      }

      // Status Card
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: statusColumn.implicitHeight + 24
        radius: 8
        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.05)
        border { color: root.border; width: 1 }
        ColumnLayout {
          id: statusColumn
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
          spacing: 8
          RowLayout {
            Layout.fillWidth: true
            Text {
              Layout.fillWidth: true
              text: Model.statusLabel(root.snapshot)
              textFormat: Text.PlainText
              color: root.ink
              font { family: root.fontFamily; pixelSize: root.fontSize + 2; bold: true }
              wrapMode: Text.WordWrap
            }
            // Status indicator
            Rectangle {
              Layout.preferredWidth: 8
              Layout.preferredHeight: 8
              Layout.alignment: Qt.AlignVCenter
              radius: 4
              color: root.snapshot.enabled ? root.success : (root.snapshot.paused ? root.warning : root.error)
              visible: root.snapshot.installed
            }
          }
          Text {
            Layout.fillWidth: true
            text: "Theme: " + (root.paletteInfo.name || "not inspected")
                  + (root.paletteInfo.mode && root.paletteInfo.mode !== "unknown" ? " · " + root.paletteInfo.mode : "")
                  + "\nContrast: " + (root.paletteInfo.worst && root.paletteInfo.worst !== "unknown" ? root.paletteInfo.worst + ":1" : "—")
                  + "  (target " + (root.paletteInfo.minimum || "5.5") + ":1)"
            textFormat: Text.PlainText
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.75)
            font { family: root.fontFamily; pixelSize: root.fontSize }
            wrapMode: Text.WordWrap
          }
          Text {
            Layout.fillWidth: true
            text: "Contrast covers theme-managed foregrounds; custom styles are excluded."
            textFormat: Text.PlainText
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.5)
            font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
            wrapMode: Text.WordWrap
          }
          Text {
            Layout.fillWidth: true
            text: "Plugin v" + (root.snapshot.pluginVersion || "—") + "  ·  Bash v" + (root.snapshot.installedVersion || "not installed")
                  + (root.snapshot.updateAvailable ? "  ·  Update available" : "")
            textFormat: Text.PlainText
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.5)
            font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
            wrapMode: Text.WordWrap
          }
        }
      }

      // Palette/Config warnings
      Text {
        Layout.fillWidth: true
        visible: (root.snapshot.paletteError || root.paletteInfo.warnings) && String(root.snapshot.paletteError || root.paletteInfo.warnings).length > 0
        text: String(root.snapshot.paletteError || root.paletteInfo.warnings || "")
        textFormat: Text.PlainText
        color: root.warning
        font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
        wrapMode: Text.WrapAnywhere
      }

      // BTW Hint Card
      Rectangle {
        Layout.fillWidth: true
        visible: root.showBtw && root.btwHint
        implicitHeight: btwColumn.implicitHeight + 20
        radius: 8
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.10)
        border { color: root.accent; width: 1 }
        ColumnLayout {
          id: btwColumn
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
          spacing: 10
          RowLayout {
            Layout.fillWidth: true
            Text {
              Layout.fillWidth: true
              text: "💡  BTW: " + root.btwHint.title
              textFormat: Text.PlainText
              color: root.accent
              font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
              wrapMode: Text.WordWrap
            }
            ActionButton {
              text: "×"
              Layout.preferredWidth: 32
              Layout.preferredHeight: 32
              font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
              ink: root.ink; surface: root.surface; accent: root.accent
              onClicked: root.dismissBtwHint()
              Accessible.name: "Dismiss hint"
            }
          }
          Text {
            Layout.fillWidth: true
            text: root.btwHint.body
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
            wrapMode: Text.WordWrap
          }
          RowLayout {
            Layout.fillWidth: true
            Text {
              Layout.fillWidth: true
              text: "Lesson " + root.btwHint.lesson + " covers this"
              textFormat: Text.PlainText
              color: root.accent
              font { family: root.fontFamily; pixelSize: root.fontSize - 1; italic: true }
            }
            ActionButton {
              text: "Want to do it now?"
              Layout.preferredHeight: 36
              font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
              ink: root.ink; surface: root.surface; accent: root.accent
              emphasized: true
              onClicked: root.doBtwAction()
            }
          }
        }
      }

      // Action Grid
      GridLayout {
        Layout.fillWidth: true
        columns: root.width >= 480 ? 3 : 2
        rowSpacing: 10
        columnSpacing: 10
        Repeater {
          model: [
            {action: "setup", label: "Set up in terminal", icon: "⚙️", primary: (root.snapshot.installed !== true || root.snapshot.updateAvailable === true)},
            {action: root.snapshot.paused ? "enable" : "disable", label: root.snapshot.paused ? "Enable" : "Disable", icon: root.snapshot.paused ? "▶️" : "⏸️", primary: false},
            {action: "reload", label: "Reload theme", icon: "🔄", primary: false},
            {action: "doctor", label: "Doctor", icon: "🩺", primary: false},
            {action: "legend", label: "Legend", icon: "🎨", primary: false},
            {action: "inspect", label: "Refresh status", icon: "🔍", primary: false},
            {action: "ai", label: "AI Stylist", icon: "✨", primary: true},
            {action: "learn", label: "Learn / Library", icon: "📚", primary: false}
          ]
          ActionButton {
            required property var modelData
            objectName: "action-" + modelData.action
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.minimumHeight: 44
            text: modelData.icon + "  " + modelData.label
            ink: root.ink
            surface: root.surface
            accent: root.accent
            accentHover: root.accentHover
            accentPressed: root.accentPressed
            emphasized: modelData.primary
            font { family: root.fontFamily; pixelSize: root.fontSize }
            enabled: !root.busy && !root.pendingAction && (root.snapshot.installed || ["setup", "legend", "inspect", "ai", "learn"].indexOf(modelData.action) >= 0)
            onClicked: {
              if (modelData.action === "setup") root.beginSetup();
              else root.choose(modelData.action);
            }
            // Busy state
            property bool localBusy: root.busy && root.action === modelData.action
          }
        }
      }

      // Confirmation Dialog
      Rectangle {
        Layout.fillWidth: true
        visible: root.pendingAction.length > 0
        implicitHeight: confirmColumn.implicitHeight + 28
        radius: 8
        color: root.surface
        border { color: root.ink; width: 1 }
        ColumnLayout {
          id: confirmColumn
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
          spacing: 16
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
            spacing: 10
            ActionButton {
              id: cancelButton
              objectName: "cancel"
              Layout.fillWidth: true
              text: "Cancel"
              ink: root.ink; surface: root.surface; accent: root.accent
              font { family: root.fontFamily; pixelSize: root.fontSize }
              onClicked: root.pendingAction = ""
              Accessible.name: "Cancel " + root.pendingAction
            }
            ActionButton {
              objectName: "confirm"
              Layout.fillWidth: true
              text: "Confirm"
              ink: root.ink; surface: root.surface; accent: root.accent
              accentHover: root.accentHover
              accentPressed: root.accentPressed
              font { family: root.fontFamily; pixelSize: root.fontSize }
              enabled: !root.busy
              emphasized: true
              onClicked: root.confirmPending()
              Accessible.name: "Confirm " + root.pendingAction
            }
          }
        }
      }

      // Message/Output Area
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.message.length > 0 || root.output.length > 0
        Text {
          Layout.fillWidth: true
          visible: root.message.length > 0
          text: (root.failed ? "⚠  " : "") + root.message
          textFormat: Text.PlainText
          color: root.failed ? root.error : root.accent
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
          background: Rectangle {
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.05)
            radius: 6
            border { color: root.border; width: 1 }
          }
          padding: 10
          maximumHeight: 300
          Accessible.name: "Command output"
        }
      }

      // Color Legend
      ColumnLayout {
        Layout.fillWidth: true
        visible: root.showLegend
        spacing: 10
        RowLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            text: "COLOR LEGEND · examples are never executed"
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
            wrapMode: Text.WordWrap
          }
          ActionButton {
            text: "× Close"
            Layout.preferredHeight: 32
            Layout.minimumWidth: 80
            font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
            ink: root.ink; surface: root.surface; accent: root.accent
            onClicked: root.showLegend = false
            Accessible.name: "Close legend"
          }
        }
        Repeater {
          model: root.snapshot.legend || []
          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: legendColumn.implicitHeight + 16
            radius: 6
            color: /^#[0-9a-fA-F]{6}$/.test(root.paletteInfo.background || "") ? root.paletteInfo.background : root.surface
            border { color: root.border; width: 1 }
            ColumnLayout {
              id: legendColumn
              anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
              spacing: 4
              RowLayout {
                Layout.fillWidth: true
                Text {
                  Layout.fillWidth: true
                  text: String(modelData.category || "other").toUpperCase() + "  ·  " + String(modelData.example || "")
                  textFormat: Text.PlainText
                  color: modelData.color || root.ink
                  font { family: "monospace"; pixelSize: root.fontSize; bold: true; underline: String(modelData.style || "").indexOf("underline") >= 0 }
                  wrapMode: Text.WordWrap
                }
                Text {
                  text: (modelData.ratio && modelData.ratio !== "unknown") ? modelData.ratio + ":1" : "—"
                  textFormat: Text.PlainText
                  color: Qt.rgba(modelData.color || root.ink, 0.7)
                  font { family: root.fontFamily; pixelSize: root.fontSize - 1; bold: true }
                }
              }
              Text {
                Layout.fillWidth: true
                text: (modelData.style || "plain") + (modelData.ratio && modelData.ratio !== "unknown" ? " · " + modelData.ratio + ":1" : " · custom/indexed style")
                textFormat: Text.PlainText
                color: Qt.rgba(modelData.color || root.ink, 0.65)
                font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
                wrapMode: Text.WrapAnywhere
              }
            }
          }
        }
        // Empty state
        Text {
          Layout.fillWidth: true
          visible: !root.snapshot.legend || root.snapshot.legend.length === 0
          text: "No legend data available. Run 'chroma doctor' or click Refresh status."
          textFormat: Text.PlainText
          color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
          font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
          wrapMode: Text.WordWrap
        }
      }

      // Learn / Library
      ColumnLayout {
        Layout.fillWidth: true
        visible: root.showLearn
        spacing: 10
        RowLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            text: "LEARN / LIBRARY · Knowunity-style lessons & snippets"
            textFormat: Text.PlainText
            color: root.ink
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
            wrapMode: Text.WordWrap
          }
          ActionButton {
            text: "× Close"
            Layout.preferredHeight: 32
            Layout.minimumWidth: 80
            font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
            ink: root.ink; surface: root.surface; accent: root.accent
            onClicked: root.showLearn = false
            Accessible.name: "Close library"
          }
        }
        Text {
          Layout.fillWidth: true
          text: "Lessons are bundled in the plugin. Open the GitHub README for the full lesson book.\nSearch, tag, and track progress — community contributions welcome via PR."
          textFormat: Text.PlainText
          color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
          font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
          wrapMode: Text.WordWrap
        }
        ColumnLayout {
          spacing: 8
          Repeater {
            model: [
              {id: "L01", title: "Install & verify Chroma", tags: ["setup", "basics"], desc: "Run the terminal installer and verify with chroma doctor"},
              {id: "L02", title: "Read & write config.bash", tags: ["config", "styles"], desc: "Customize CHROMA_STYLES, extra commands, contrast target"},
              {id: "L03", title: "Build a custom Omarchy theme", tags: ["theme", "colors.toml"], desc: "Create colors.toml + theme.name with proper contrast"},
              {id: "L04", title: "Write a semantic highlight rule", tags: ["parser", "advanced"], desc: "Extend lib/parser.bash for your own CLI tools"},
              {id: "L05", title: "Create an Omarchy plugin", tags: ["plugin", "qml", "bash"], desc: "Scaffold manifest.json, BarWidget, Backend, install.sh"},
              {id: "L06", title: "Use the Chroma Stylist (AI)", tags: ["ai", "stylist", "ollama", "opencode"], desc: "Generate themes, configs, plugins with local AI"},
              {id: "L07", title: "Debug with chroma doctor/explain", tags: ["debug", "doctor"], desc: "Diagnose highlighting, theme, config issues"}
            ]
            Rectangle {
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: lessonColumn.implicitHeight + 16
              radius: 8
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.08)
              border { color: root.accent; width: 1 }
              ColumnLayout {
                id: lessonColumn
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                spacing: 6
                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    Layout.fillWidth: true
                    text: modelData.id + "  " + modelData.title
                    textFormat: Text.PlainText
                    color: root.ink
                    font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                    wrapMode: Text.WordWrap
                  }
                  Text {
                    text: modelData.id
                    textFormat: Text.PlainText
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6)
                    font { family: "monospace"; pixelSize: root.fontSize - 1; bold: true }
                  }
                }
                Text {
                  Layout.fillWidth: true
                  text: modelData.desc
                  textFormat: Text.PlainText
                  color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
                  font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
                  wrapMode: Text.WordWrap
                }
                RowLayout {
                  Repeater {
                    model: modelData.tags
                    Text {
                      text: "#" + modelData
                      textFormat: Text.PlainText
                      color: root.accent
                      font { family: root.fontFamily; pixelSize: root.fontSize - 2; bold: true }
                    }
                  }
                }
              }
            }
          }
        }
        // Empty state
        Text {
          Layout.fillWidth: true
          visible: false // Always has content
        }
        Rectangle {
          Layout.fillWidth: true
          height: 1
          color: root.border
          visible: true
        }
        Text {
          Layout.fillWidth: true
          text: "Full lesson book: GitHub README  ·  Contribute: PR to docs/lessons/"
          textFormat: Text.PlainText
          color: root.accent
          font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
          wrapMode: Text.WordWrap
        }
      }

      // Footer
      Text {
        Layout.fillWidth: true
        text: "Enable/disable applies to NEW terminals. Theme reload reaches already loaded Chroma shells at their next prompt. Code/config changes need a new terminal.\n\nThis widget and the Bash add-on have separate lifetimes. Remove the Bash integration below before removing the widget if you want both gone."
        textFormat: Text.PlainText
        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
        font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
        wrapMode: Text.WordWrap
      }
      ActionButton {
        Layout.fillWidth: true
        text: "Remove Bash integration…"
        ink: root.ink; surface: root.surface; accent: root.accent
        destructive: true
        font { family: root.fontFamily; pixelSize: root.fontSize }
        enabled: root.snapshot.installed === true && !root.busy && !root.pendingAction
        onClicked: root.choose("uninstall")
        Accessible.name: "Remove Bash integration"
      }
    }
  }
}