import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import vm from 'node:vm';

// Run the actual service with deterministic platform substitutes; no device required.
const require = createRequire(import.meta.url);
const sdk = process.env.DEVECO_SDK_HOME || process.argv[2];
assert.ok(sdk, 'Set DEVECO_SDK_HOME or pass the SDK directory.');
const ts = require(resolve(sdk, 'default/openharmony/ets/build-tools/ets-loader/node_modules/typescript'));
const source = readFileSync(new URL('../entry/src/main/ets/service/AudioService.ets', import.meta.url), 'utf8');
const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText;


function fixture() {
  let opens = 0, closes = 0, creates = 0, releases = 0;
  let failOpen = false, failPrepare = false;
  const players = [];
  const manager = {
    async getRawFd() {
      opens++;
      if (failOpen) throw new Error('Missing rawfile');
      return { fd: 7, offset: 128, length: 44144 };
    },
    async closeRawFd() { closes++; }
  };
  const media = {
    async createAVPlayer() {
      creates++;
      const callbacks = {};
      const player = {
        state: 'idle',
        on(name, callback) { callbacks[name] = callback; },
        set fdSrc(value) {
          assert.deepEqual({ ...value }, { fd: 7, offset: 128, length: 44144 });
          queueMicrotask(() => callbacks.stateChange('initialized'));
        },
        async prepare() {
          if (failPrepare) throw new Error('Decoder failure');
          player.state = 'prepared';
          callbacks.stateChange('prepared');
        },
        async play() { player.state = 'playing'; },
        async pause() { player.state = 'paused'; },
        async release() { releases++; player.state = 'released'; },
        error() { player.state = 'error'; callbacks.error(new Error('Runtime failure')); }
      };
      players.push(player);
      return player;
    }
  };
  const exports = {};
  vm.runInNewContext(compiled, {
    exports, setTimeout, clearTimeout, Promise,
    require(name) {
      if (name === '@kit.MediaKit') return { media };
      throw new Error(`Unexpected import: ${name}`);
    }
  });
  return {
    service: exports.AudioService.getInstance(), manager, players,
    counts: () => ({ opens, closes, creates, releases }),
    failOpen(value) { failOpen = value; },
    failPrepare(value) { failPrepare = value; }
  };
}

{
  const f = fixture();
  const first = f.service.initialize(f.manager);
  assert.equal(first, f.service.initialize(f.manager), 'Concurrent calls must share the pending promise');
  await Promise.all([first, f.service.initialize(f.manager)]);
  await f.service.initialize(f.manager);
  assert.equal(f.service.getInitializationCount(), 1);
  assert.deepEqual(f.counts(), { opens: 1, closes: 0, creates: 1, releases: 0 });
  await f.service.release();
  assert.deepEqual(f.counts(), { opens: 1, closes: 1, creates: 1, releases: 1 });
}
{
  const f = fixture();
  f.failOpen(true);
  await assert.rejects(f.service.initialize(f.manager), /Missing rawfile/);
  f.failOpen(false);
  await f.service.initialize(f.manager);
  assert.equal(f.service.getInitializationCount(), 1);
  await f.service.release();
}
{
  const f = fixture();
  f.failPrepare(true);
  await assert.rejects(f.service.initialize(f.manager), /Decoder failure/);
  assert.deepEqual(f.counts(), { opens: 1, closes: 1, creates: 1, releases: 1 });
  f.failPrepare(false);
  await f.service.initialize(f.manager);
  await f.service.release();
}
{
  const f = fixture();
  const init = f.service.initialize(f.manager);
  const release = f.service.release();
  assert.equal(release, f.service.release());
  await Promise.all([init, release]);
  assert.deepEqual(f.counts(), { opens: 1, closes: 1, creates: 1, releases: 1 });
  await f.service.initialize(f.manager);
  assert.equal(f.service.getInitializationCount(), 2);
  await f.service.release();
}
{
  const f = fixture();
  await f.service.initialize(f.manager);
  await f.service.setForeground(false);
  await f.service.play(f.manager);
  assert.equal(f.players[0].state, 'prepared');
  await f.service.setForeground(true);
  await f.service.play(f.manager);
  await f.service.setForeground(false);
  assert.equal(f.players[0].state, 'paused');
  f.players[0].error();
  await f.service.initialize(f.manager);
  assert.deepEqual(f.counts(), { opens: 2, closes: 1, creates: 2, releases: 1 });
  await f.service.release();
}
console.log('PASS: injected ResourceManager, concurrent and repeated init, missing rawfile retry, prepare failure cleanup, release during init, foreground pause, runtime error recovery.');
