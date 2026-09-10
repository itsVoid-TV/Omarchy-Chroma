import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui as Ui
import "Model.js" as Model

Ui.BarWidget {
  id: root
  moduleName: "io.github.itsvoid-tv.command-chroma"
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open(); }
  function close() { if (panelLoader.item) panelLoader.item.close(); }
  function toggle() { if (root.opened) root.close(); else root.open(); }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch(); }
  function refresh() { controlBackend.request(root.opened ? "inspect" : "status", false); }
  function injectPanel() {
    if (!panelLoader.item) return;
    panelLoader.item.bar = root.bar;
    panelLoader.item.anchorItem = button;
    panelLoader.item.hostWidget = root;
    panelLoader.item.backend = controlBackend;
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  Component.onCompleted: root.refresh()

  Backend { id: controlBackend }

  Loader {
    id: panelLoader
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel); }
  }

  IpcHandler {
    target: "io.github.itsvoid-tv.command-chroma"
    function open(): void { root.open(); }
    function show(): void { root.open(); }
    function close(): void { root.close(); }
    function hide(): void { root.close(); }
    function toggle(): void { root.toggle(); }
    function refresh(): void { root.broadcast("refresh"); }
  }

  Timer {
    interval: 30000
    running: root.visible
    repeat: true
    onTriggered: root.refresh()
  }

  Ui.BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf120"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.body
    tooltipText: "Command Chroma · " + Model.statusLabel(controlBackend.snapshot)
    onPressed: root.toggle()
    Rectangle {
      width: 5
      height: 5
      radius: 3
      anchors { right: parent.right; bottom: parent.bottom; margins: 3 }
      visible: controlBackend.snapshot.enabled === true
      color: root.bar ? root.bar.foreground : Color.foreground
    }
  }
}
