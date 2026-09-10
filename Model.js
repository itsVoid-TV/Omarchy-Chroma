// Shared, side-effect-free UI decisions. No shell commands are constructed here.
function statusLabel(data) {
  if (!data || !data.state) return "Checking installation…";
  if (data.state === "enabled") return "Enabled for new terminals";
  if (data.state === "disabled") return "Disabled for new terminals";
  if (data.state === "needs-attention") return "Setup needs attention";
  return "Bash integration not installed";
}

function confirmation(action, data) {
  var bashrc = data && data.bashrc ? data.bashrc : "your .bashrc";
  if (action === "setup") return "Install this plugin's bundled Bash code in your user data directory and add one marked loader to " + bashrc + "? A backup is saved first. Existing settings are preserved. If ble.sh is missing, one pinned, checksum-verified build is downloaded from GitHub. No sudo.";
  if (action === "uninstall") return "Remove the Bash integration and its marked .bashrc loader? Your settings, ble.sh, and backups are kept. Existing terminals keep their loaded code until closed. This does not remove the Omarchy widget.";
  if (action === "disable") return "Disable Chroma for newly opened Bash terminals? Existing terminals keep their current colors. Hiding this widget alone does not disable the Bash add-on.";
  if (action === "enable") return "Enable Chroma for newly opened Bash terminals? Existing terminals are not restarted or modified.";
  return "";
}

function needsConfirmation(action) {
  return ["setup", "enable", "disable", "uninstall"].indexOf(action) !== -1;
}

function validReply(reply) {
  return reply && reply.schemaVersion === 1 && typeof reply.ok === "boolean"
      && typeof reply.message === "string";
}

if (typeof module !== "undefined") module.exports = {
  statusLabel: statusLabel, confirmation: confirmation,
  needsConfirmation: needsConfirmation, validReply: validReply
};
