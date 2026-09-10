import QtQuick
import QtTest
import "../../ui" as Ui

Rectangle {
  id: scene
  width: 600
  height: 720
  color: view.surface
  Ui.ControlView {
    id: view
    anchors { fill: parent; margins: 16 }
  }
  SignalSpy { id: requestSpy; target: view; signalName: "requested" }
  SignalSpy { id: closeSpy; target: view; signalName: "closeRequested" }

  TestCase {
    name: "ControlView"
    when: windowShown

    function init() {
      failOnWarning(/.?/);
      scene.width = 600;
      view.snapshot = {state: "enabled", installed: true, enabled: true, paused: false,
        pluginVersion: "0.4.0", installedVersion: "0.4.0", bashrc: "/home/example/.bashrc",
        palette: {name: "Vantablack", mode: "dark", background: "#000000", minimum: "5.5", worst: "5.512"}};
      view.ink = "#eeeeee";
      view.surface = "#171717";
      view.pendingAction = "";
      view.showLegend = false;
      view.busy = false;
      view.message = "";
      view.output = "";
      requestSpy.clear();
      closeSpy.clear();
      wait(20);
    }

    function test_setup_requires_confirm() {
      var setup = findChild(view, "action-setup");
      verify(setup);
      mouseClick(setup);
      compare(view.pendingAction, "setup");
      compare(requestSpy.count, 0);
      view.confirmPending();
      compare(requestSpy.count, 1);
      compare(requestSpy.signalArguments[0][0], "setup");
      compare(requestSpy.signalArguments[0][1], true);
      compare(view.pendingAction, "");
    }

    function test_cancel_has_no_action() {
      view.choose("disable");
      var cancel = findChild(view, "cancel");
      verify(cancel);
      // Direct key handling verifies the real focus/cancellation route.
      view.forceActiveFocus();
      keyClick(Qt.Key_Escape);
      compare(view.pendingAction, "");
      compare(requestSpy.count, 0);
      compare(closeSpy.count, 0);
      keyClick(Qt.Key_Escape);
      compare(closeSpy.count, 1);
    }

    function test_busy_blocks_actions() {
      view.busy = true;
      view.choose("setup");
      compare(view.pendingAction, "");
      compare(requestSpy.count, 0);
      verify(!findChild(view, "action-setup").enabled);
    }

    function test_legend_and_doctor() {
      view.choose("legend");
      compare(view.showLegend, true);
      compare(requestSpy.signalArguments[0][0], "legend");
      compare(requestSpy.signalArguments[0][1], false);
      view.choose("doctor");
      compare(requestSpy.signalArguments[1][0], "doctor");
    }

    function test_render_dark_light_narrow() {
      verify(waitForRendering(view));
      grabImage(scene).save("chroma-dark.png");
      view.surface = "#ffffff";
      view.ink = "#222222";
      view.snapshot = {state: "disabled", installed: true, paused: true,
        pluginVersion: "0.4.0", installedVersion: "0.4.0",
        palette: {name: "White", mode: "light", background: "#ffffff", minimum: "5.5", worst: "5.530"}};
      verify(waitForRendering(view));
      grabImage(scene).save("chroma-light.png");
      scene.width = 360;
      view.choose("uninstall");
      verify(waitForRendering(view));
      grabImage(scene).save("chroma-narrow.png");
      verify(findChild(view, "action-setup").width > 80);
    }
  }
}
