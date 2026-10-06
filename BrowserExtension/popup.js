const token = document.getElementById("token");
const status = document.getElementById("status");
const mode = document.getElementById("mode");
async function refresh() {
  const saved = await chrome.storage.local.get(["token", "connectionStatus", "statusAt", "followedTabId"]);
  token.value = saved.token || "";
  status.textContent = saved.statusAt && Date.now() - saved.statusAt < 5000 ? saved.connectionStatus : "Open LyricFloat and play a YouTube video to connect.";
  mode.textContent = saved.followedTabId != null ? "Following your selected tab. Auto-select clears this choice." : "Auto-select follows the first playing YouTube tab.";
}
document.getElementById("save").addEventListener("click", async () => {
  const value = token.value.trim();
  if (!/^[0-9a-f-]{36}$/i.test(value)) { status.textContent = "Copy the full pairing code from LyricFloat’s Connect browser screen."; return; }
  await chrome.storage.local.set({token: value});
  status.textContent = "Saved. Reload your YouTube tab and start playback.";
});
document.getElementById("follow").addEventListener("click", async () => {
  const [tab] = await chrome.tabs.query({active: true, currentWindow: true});
  if (!tab || !/^https:\/\/(www|music)\.youtube\.com\//.test(tab.url || "")) { status.textContent = "Open this popup from a YouTube video tab first."; return; }
  await chrome.storage.local.set({followedTabId: tab.id});
  mode.textContent = "Following this YouTube tab.";
});
document.getElementById("auto").addEventListener("click", async () => {
  await chrome.storage.local.remove("followedTabId");
  mode.textContent = "Auto-select follows the first playing YouTube tab.";
});
refresh();
