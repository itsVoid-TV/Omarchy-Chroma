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
      view.setupFlowActive = false;
      view.busy = false;
      view.message = "";
      view.output = "";
      requestSpy.clear();
      closeSpy.clear();
      wait(20);
    }

    function test_dashboard_setup_opens_guided_review() {
      var setup = findChild(view, "action-setup");
      verify(setup);
      mouseClick(setup);
      compare(view.setupFlowActive, true);
      compare(requestSpy.count, 0);
      wait(20);
      mouseClick(findChild(view, "setup-next"));
      compare(requestSpy.count, 0);
      mouseClick(findChild(view, "setup-install"));
      compare(requestSpy.count, 1);
      compare(requestSpy.signalArguments[0][0], "setup");
      compare(requestSpy.signalArguments[0][1], true);
    }

    function test_first_install_success_and_retry_routes() {
      view.snapshot = {state: "not-installed", installed: false, enabled: false,
        pluginVersion: "0.4.0", bashrc: "/home/example/.bashrc",
        installPath: "/home/example/.local/share/omarchy-chroma", blePath: "",
        palette: {name: "Vantablack", mode: "dark", background: "#000000", minimum: "5.5", worst: "5.512"},
        legend: [{category: "install", color: "#cecece"}, {category: "danger", color: "#ff6b7a"},
                 {category: "network", color: "#63d4ed"}, {category: "inspect", color: "#b8c0ff"}]};
      wait(20);
      compare(view.setupFlowActive, true);
      mouseClick(findChild(view, "setup-next"));
      mouseClick(findChild(view, "setup-install"));
      compare(requestSpy.signalArguments[0][0], "setup");
      compare(requestSpy.signalArguments[0][1], true);
      view.failed = true;
      view.message = "Fixture failure";
      wait(20);
      verify(findChild(view, "setup-retry").visible);
      mouseClick(findChild(view, "setup-retry"));
      compare(requestSpy.count, 2);
      view.failed = false;
      view.snapshot = {state: "enabled", installed: true, enabled: true,
        pluginVersion: "0.4.0", installedVersion: "0.4.0",
        palette: {name: "Vantablack", mode: "dark", background: "#000000", minimum: "5.5", worst: "5.512"}};
      wait(20);
      var done = findChild(view, "setup-done");
      verify(done.visible);
      mouseClick(done);
      compare(view.setupFlowActive, false);
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
      // grabImage renders synchronously. Waiting for a future frameSwapped
      // signal after init's frame is already complete can time out on Qt 6.4.
      var dark = grabImage(scene);
      compare(dark.width, 600);
      compare(dark.height, 720);
      compare(dark.red(2, 2), 23);
      dark.save("chroma-dark.png");
      view.surface = "#ffffff";
      view.ink = "#222222";
      view.snapshot = {state: "disabled", installed: true, paused: true,
        pluginVersion: "0.4.0", installedVersion: "0.4.0",
        palette: {name: "White", mode: "light", background: "#ffffff", minimum: "5.5", worst: "5.530"}};
      wait(20);
      var light = grabImage(scene);
      compare(light.red(2, 2), 255);
      verify(!light.equals(dark));
      light.save("chroma-light.png");
      scene.width = 360;
      view.choose("uninstall");
      wait(20);
      var narrow = grabImage(scene);
      compare(narrow.width, 360);
      narrow.save("chroma-narrow.png");
      verify(findChild(view, "action-setup").width > 80);
    }

    function test_render_installer_welcome_and_review() {
      view.snapshot = {state: "not-installed", installed: false, enabled: false,
        pluginVersion: "0.4.0", bashrc: "/home/example/.bashrc",
        installPath: "/home/example/.local/share/omarchy-chroma", blePath: "",
        palette: {name: "Vantablack", mode: "dark", background: "#000000", minimum: "5.5", worst: "5.512"},
        legend: [{category: "install", color: "#cecece"}, {category: "danger", color: "#ff6b7a"},
                 {category: "network", color: "#63d4ed"}, {category: "inspect", color: "#b8c0ff"}]};
      wait(20);
      var welcome = grabImage(scene);
      compare(welcome.width, 600);
      welcome.save("chroma-installer-welcome.png");
      mouseClick(findChild(view, "setup-next"));
      wait(20);
      var review = grabImage(scene);
      verify(!review.equals(welcome));
      review.save("chroma-installer-review.png");
    }
  }
}
