let active = null;
let lastStatusWrite = 0;
let cachedSettings = null;
chrome.storage.onChanged.addListener(() => { cachedSettings = null; });
async function settings() {
  if (!cachedSettings) cachedSettings = await chrome.storage.local.get(["token", "followedTabId"]);
  return cachedSettings;
}
async function status(message) {
  if (Date.now() - lastStatusWrite > 1500) {
    lastStatusWrite = Date.now();
    await chrome.storage.local.set({connectionStatus: message, statusAt: Date.now()});
  }
}
chrome.runtime.onMessage.addListener((message, sender, reply) => {
  if (message.type !== "playback" || !sender.tab || !/^https:\/\/(www|music)\.youtube\.com\//.test(sender.url || "")) return;
  (async () => {
    const config = await settings();
    if (!config.token) { await status("Paste the app’s pairing code to connect."); return {}; }
    const sample = message.snapshot;
    if (!sample || !Number.isFinite(sample.position) || !Number.isFinite(sample.duration)) return {};
    const tabId = sender.tab.id;
    if (config.followedTabId != null && config.followedTabId !== tabId) return {};
    const now = Date.now();
    if (config.followedTabId == null) {
      const same = active?.tabId === tabId;
      const canSwitch = !active || now - active.seen > 3500 || (!active.playing && sample.playing);
      if (!same && !canSwitch) return {};
    }
    active = {tabId, seen: now, playing: sample.playing};
    try {
      const response = await fetch("http://127.0.0.1:18473/playback", {
        method: "POST",
        headers: {"Content-Type": "application/json", "X-LyricFloat-Token": config.token},
        body: JSON.stringify(sample),
        signal: AbortSignal.timeout(2000)
      });
      if (!response.ok) {
        await status(response.status === 403 ? "Pairing code does not match. Copy it again from the app." : "The app could not read this playback update.");
        return {};
      }
      await status("Connected · " + sample.title);
      return await response.json();
    } catch {
      await status("App not reachable. Open LyricFloat on this Mac.");
      return {};
    }
  })().then(reply).catch(() => reply({}));
  return true;
});
chrome.tabs.onRemoved.addListener(async tabId => {
  if (active?.tabId === tabId) active = null;
  const config = await settings();
  if (config.followedTabId === tabId) await chrome.storage.local.remove("followedTabId");
});
