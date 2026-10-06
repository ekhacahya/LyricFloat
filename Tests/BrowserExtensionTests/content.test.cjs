const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
function page() {
  let now = 1000;
  let title = 'First song';
  const events = {};
  const calls = [];
  let resolveMessage;
  const video = {duration: 180, currentTime: 170, paused: false, ended: false, readyState: 4, playbackRate: 1, addEventListener() {}, removeEventListener() {}, pause() {this.paused = true;}, async play() {this.paused = false;}};
  const location = {href: 'https://www.youtube.com/watch?v=first&list=playlist'};
  let interval;
  const context = {URL, Number, Date: {now: () => now}, location,
    setInterval(fn) {interval = fn;},
    document: {title: '', addEventListener(name, fn) {events[name] = fn;}, querySelector(selector) {
      if (selector === 'video.html5-main-video, video') return video;
      if (selector.includes('ytd-watch-metadata h1')) return {textContent: title};
      if (selector.includes('#owner')) return {textContent: 'Artist'};
      return null;
    }},
    chrome: {runtime: {sendMessage(message) {calls.push(message); return new Promise(resolve => {resolveMessage = resolve;});}}}
  };
  vm.runInNewContext(fs.readFileSync('BrowserExtension/content.js', 'utf8'), context);
  return {calls, video, location, events, tick: () => {now += 600; interval();}, title: text => {title = text;}, reply: response => resolveMessage(response)};
}
const settle = () => new Promise(resolve => setImmediate(resolve));
test('playlist navigation sends fresh identity and real position', async () => {
  const p = page(); p.reply({}); await settle();
  p.events['yt-navigate-start'](); p.location.href = 'https://www.youtube.com/watch?v=second&list=playlist';
  p.title('Second song'); p.video.currentTime = 0; p.tick();
  assert.equal(p.calls.length, 1);
  p.events['yt-navigate-finish'](); p.tick();
  assert.equal(p.calls.at(-1).snapshot.id, 'youtube:second');
  assert.equal(p.calls.at(-1).snapshot.title, 'Second song');
  assert.equal(p.calls.at(-1).snapshot.position, 0);
});
test('late command from previous song cannot seek the new song', async () => {
  const p = page(); p.events['yt-navigate-start']();
  p.location.href = 'https://www.youtube.com/watch?v=second'; p.video.currentTime = 0;
  p.reply({command: {type: 'seek', position: 170}}); await settle();
  assert.equal(p.video.currentTime, 0);
});
