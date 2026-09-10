import QtQuick
import qs.Commons
import qs.Ui as Ui
import "ui" as ChromaUi

Ui.Panel {
  id: root
  moduleName: "io.github.itsvoid-tv.command-chroma"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  property var backend: null

  function open() {
    view.pendingAction = "";
    root.controller.show();
    if (root.backend) root.backend.request("inspect", false);
  }

  function close() {
    view.pendingAction = "";
    root.controller.hide();
  }

  Ui.KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: view
    contentWidth: panel.fittedContentWidth(Style.space(600))
    contentHeight: panel.cappedContentHeight(Style.space(650))

    ChromaUi.ControlView {
      id: view
      anchors.fill: parent
      snapshot: root.backend ? root.backend.snapshot : ({})
      busy: root.backend ? root.backend.busy : false
      failed: root.backend ? root.backend.failed : false
      message: root.backend ? root.backend.message : ""
      output: root.backend ? root.backend.output : ""
      ink: Color.popups.text
      surface: Color.popups.background
      accent: Color.accent
      fontFamily: Style.font.family
      fontSize: Style.font.body
      onRequested: function(action, confirmed) {
        if (root.backend) root.backend.request(action, confirmed);
      }
      onCloseRequested: root.close()
    }
  }
}
