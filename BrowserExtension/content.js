(() => {
  let busy = false;
  let video = null;
  let lastSent = 0;
  let navigationRevision = 0;
  let navigating = false;
  let lastMetadata = {title: "YouTube", artist: "YouTube"};
  async function report() {
    if (navigating || busy || !video || Date.now() - lastSent < 200) return;
    const id = new URL(location.href).searchParams.get("v");
    if (!id || !Number.isFinite(video.duration) || video.duration <= 0) return;
    const advertisement = Boolean(document.querySelector(".ad-showing, .ad-interrupting"));
    if (!advertisement) {
      const musicTitle = document.querySelector("ytmusic-player-bar .title");
      const standardTitle = document.querySelector("ytd-watch-metadata h1 yt-formatted-string, #title h1 yt-formatted-string");
      const musicArtist = document.querySelector("ytmusic-player-bar .byline yt-formatted-string");
      const standardArtist = document.querySelector("ytd-watch-metadata #owner #channel-name a, #owner ytd-channel-name a");
      lastMetadata = {
        title: (musicTitle?.textContent || standardTitle?.textContent || document.title.replace(/ - YouTube$/, "")).trim().slice(0, 500),
        artist: (musicArtist?.textContent || standardArtist?.textContent || "YouTube").trim().slice(0, 300)
      };
    }
    const snapshot = {
      id: "youtube:" + id, ...lastMetadata,
      position: video.currentTime, duration: video.duration,
      playing: !video.paused && !video.ended && video.readyState >= 3,
      rate: video.playbackRate, advertisement
    };
    const sentVideo = video;
    const sentRevision = navigationRevision;
    busy = true; lastSent = Date.now();
    try {
      const response = await chrome.runtime.sendMessage({type: "playback", snapshot});
      // A response from the previous playlist song must never seek or pause the new one.
      if (sentRevision !== navigationRevision || sentVideo !== video || new URL(location.href).searchParams.get("v") !== id) return;
      const command = response?.command;
      if (!advertisement && command?.type === "toggle") {
        if (video.paused) await video.play(); else video.pause();
      } else if (!advertisement && command?.type === "seek" && Number.isFinite(command.position)) {
        video.currentTime = Math.max(0, Math.min(video.duration, command.position));
      }
    } catch { /* App closed or extension reloaded. Retry on the next update. */ }
    finally { busy = false; }
  }
  function attach() {
    const next = document.querySelector("video.html5-main-video, video");
    if (next === video) return;
    if (video) for (const event of ["timeupdate", "play", "pause", "seeked", "ratechange", "ended"]) video.removeEventListener(event, report);
    video = next;
    if (video) for (const event of ["timeupdate", "play", "pause", "seeked", "ratechange", "ended"]) video.addEventListener(event, report);
  }
  setInterval(() => { attach(); report(); }, 500);
  document.addEventListener("yt-navigate-start", () => { navigationRevision++; navigating = true; });
  document.addEventListener("yt-navigate-finish", () => {
    navigationRevision++; navigating = false;
    lastMetadata = {title: "YouTube", artist: "YouTube"};
    attach(); report();
  });
  attach(); report();
})();
