import QtQuick
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root
  visible: false
  property var snapshot: ({})
  property bool busy: false
  property bool failed: false
  property string message: ""
  property string output: ""
  property string action: ""
  property bool timedOut: false
  readonly property string helper: decodeURIComponent(
    Qt.resolvedUrl("scripts/chroma-control").toString().replace(/^file:\/\//, ""))

  function request(name, confirmed) {
    if (root.busy) return;
    if (["status", "inspect", "setup", "enable", "disable", "reload", "doctor", "legend", "uninstall"].indexOf(name) < 0) return;
    if (Model.needsConfirmation(name) && !confirmed) return;
    root.action = name;
    root.busy = true;
    root.timedOut = false;
    if (name !== "status") {
      root.failed = false;
      root.message = name === "setup" ? "Installing… a missing ble.sh may take a few minutes." : "Working…";
      root.output = "";
    }
    var argv = ["python3", root.helper, name];
    if (confirmed || name === "reload") argv.push("--confirm");
    runner.command = argv;
    watchdog.interval = name === "setup" ? 255000 : 30000;
    watchdog.restart();
    runner.running = true;
  }

  function finish(code, text, errorText) {
    watchdog.stop();
    root.busy = false;
    if (root.timedOut) return;
    try {
      var reply = JSON.parse(text);
      if (!Model.validReply(reply)) throw new Error("Invalid helper response");
      if (reply.data) {
        // Cheap background checks must not discard the last palette inspection.
        if (root.action === "status" && root.snapshot.palette) {
          reply.data.palette = root.snapshot.palette;
          reply.data.legend = root.snapshot.legend;
          reply.data.paletteError = root.snapshot.paletteError;
        }
        root.snapshot = reply.data;
      }
      if (root.action !== "status" || !reply.ok) {
        root.failed = !reply.ok || code !== 0;
        root.message = reply.message;
        root.output = String(reply.output || "").slice(0, 16000);
      }
    } catch (error) {
      root.failed = true;
      root.message = "Could not read the Chroma helper response. Check that Python 3 and Bash are installed.";
      root.output = String(errorText || text || error).slice(0, 16000);
    }
  }

  Process {
    id: runner
    stdout: StdioCollector { id: stdoutCollector; waitForEnd: true }
    stderr: StdioCollector { id: stderrCollector; waitForEnd: true }
    onExited: function(code) { root.finish(code, stdoutCollector.text, stderrCollector.text); }
  }

  Timer {
    id: watchdog
    repeat: false
    onTriggered: {
      root.timedOut = true;
      runner.running = false;
      root.busy = false;
      root.failed = true;
      root.message = "The helper did not finish. Check the installation status before retrying.";
    }
  }
}
