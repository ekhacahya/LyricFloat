const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const code = fs.readFileSync('BrowserExtension/background.js', 'utf8');
function worker() {
  let handler;
  const store = {token: 'test-token'};
  const calls = [];
  const context = {
    chrome: {
      storage: {local: {get: async () => ({...store}), set: async values => Object.assign(store, values), remove: async key => delete store[key]}, onChanged: {addListener() {}}},
      runtime: {onMessage: {addListener(fn) { handler = fn; }}},
      tabs: {onRemoved: {addListener() {}}}
    },
    Date, Number, JSON, AbortSignal,
    fetch: async (url, options) => { calls.push({url, options}); return {ok: true, json: async () => ({command: {type: 'seek', position: 12}})}; }
  };
  vm.runInNewContext(code, context);
  const send = (sample, tab = 1, url = 'https://www.youtube.com/watch?v=abc') => new Promise(resolve => {
    const handled = handler({type: 'playback', snapshot: sample}, {tab: {id: tab}, url}, resolve);
    if (!handled) resolve(undefined);
  });
  return {store, calls, send};
}
const sample = {id: 'youtube:abc', title: 'Song', artist: 'Artist', position: 10, duration: 100, playing: true, rate: 1, advertisement: false};
test('sends timing to fixed loopback endpoint and relays playback commands', async () => {
  const w = worker(); const reply = await w.send(sample);
  assert.equal(w.calls.length, 1);
  assert.equal(w.calls[0].url, 'http://127.0.0.1:18473/playback');
  assert.equal(w.calls[0].options.headers['X-LyricFloat-Token'], 'test-token');
  assert.deepEqual(JSON.parse(w.calls[0].options.body), sample);
  assert.equal(reply.command.position, 12);
});
test('ignores senders outside YouTube and non-finite playback', async () => {
  const w = worker(); await w.send(sample, 1, 'https://example.com'); await w.send({...sample, duration: Infinity});
  assert.equal(w.calls.length, 0);
});
test('does not let competing paused tabs replace the playing tab', async () => {
  const w = worker(); await w.send(sample, 1); await w.send({...sample, playing: false}, 2);
  assert.equal(w.calls.length, 1);
  await w.send({...sample, playing: false}, 1); await w.send(sample, 2);
  assert.equal(w.calls.length, 3);
});
test('honors explicitly followed tab', async () => {
  const w = worker(); w.store.followedTabId = 9;
  await w.send(sample, 1); await w.send(sample, 9);
  assert.equal(w.calls.length, 1);
});
test('does not send without a pairing code', async () => {
  const w = worker(); delete w.store.token;
  await w.send(sample);
  assert.equal(w.calls.length, 0);
});
