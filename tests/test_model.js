const assert = require("node:assert/strict");
const Model = require("../Model.js");
assert.equal(Model.statusLabel({state: "enabled"}), "Enabled for new terminals");
assert.equal(Model.statusLabel({state: "disabled"}), "Disabled for new terminals");
assert.equal(Model.statusLabel({state: "not-installed"}), "Bash integration not installed");
for (const action of ["setup", "enable", "disable", "uninstall"]) {
  assert.ok(Model.needsConfirmation(action));
  assert.ok(Model.confirmation(action, {}).length > 60);
}
assert.ok(!Model.needsConfirmation("doctor"));
assert.ok(!Model.needsConfirmation("legend"));
assert.ok(Model.confirmation("setup", {bashrc: "/tmp/path with spaces/.bashrc"}).includes("/tmp/path with spaces/.bashrc"));
assert.ok(!Model.validReply({ok: true}));
assert.ok(!Model.validReply({schemaVersion: 1, ok: "true", message: "done"}));
assert.ok(Model.validReply({schemaVersion: 1, ok: false, message: "a useful error"}));
console.log("ok - UI status, consent and JSON contract");
