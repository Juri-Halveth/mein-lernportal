const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function runtime({ fail = false } = {}) {
  const listeners = new Set();
  const frames = [];
  const timers = new Set();
  const window = {
    addEventListener(name, callback) { assert.equal(name, "message"); listeners.add(callback); },
    removeEventListener(name, callback) { assert.equal(name, "message"); listeners.delete(callback); }
  };
  const document = {
    currentScript: { src: "https://portal.invalid/path/code-runner.js" },
    createElement(tag) {
      assert.equal(tag, "iframe");
      const frame = { contentWindow: {}, setAttribute(name, value) { this[name] = value; }, remove() { this.removed = true; } };
      frames.push(frame);
      return frame;
    },
    body: { append(frame) { frame.appended = true; } }
  };
  const context = { window, document, URL, crypto, fetch: async () => ({ ok: !fail, text: async () => "worker fixture" }),
    setTimeout(callback, milliseconds) { const timer = { callback, milliseconds }; timers.add(timer); return timer; },
    clearTimeout(timer) { timers.delete(timer); } };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, "../code-runner.js"), "utf8"), context);
  async function flush() { await new Promise(setImmediate); }
  function message(frame, data, source = frame.contentWindow) { for (const callback of listeners) callback({ source, data }); }
  function id(frame) { return JSON.parse(/const data=(\{.*?\});const worker=/.exec(frame.srcdoc)[1]).id; }
  return { api: window.PortalCodeRunner, frames, listeners, timers, flush, message, id };
}

test("runtime validates input before creating a frame", async () => {
  const r = runtime();
  for (const [language, code] of [["html", "x"], ["js", null], ["python", "x".repeat(50001)]]) {
    assert.equal((await r.api.run(language, code)).ok, false);
  }
  assert.equal(r.frames.length, 0);
});

test("code is data in one opaque frame and messages require its source and run ID", async () => {
  const r = runtime();
  const result = r.api.run("js", 'console.log("</script><script>not markup</script>")');
  await r.flush();
  const frame = r.frames[0];
  assert.equal(frame.sandbox, "allow-scripts");
  assert.equal(frame.hidden, true);
  assert.equal(frame.appended, true);
  assert.match(frame.srcdoc, /default-src 'none'/);
  assert.match(frame.srcdoc, /connect-src https:\/\/cdn\.jsdelivr\.net\/pyodide\/v0\.26\.2\/full\//);
  assert.equal((frame.srcdoc.match(/<script>/g) || []).length, 1);
  const id = r.id(frame);
  r.message(frame, { id, type: "result", ok: true, output: "forged" }, {});
  r.message(frame, { id: "wrong-run", type: "result", ok: true, output: "forged" });
  assert.equal(frame.removed, undefined);
  r.message(frame, { id, type: "ready" });
  assert.deepEqual([...r.timers].map(timer => timer.milliseconds), [8000]);
  const deadline = [...r.timers][0];
  r.message(frame, { id, type: "ready" });
  assert.equal([...r.timers][0], deadline, "untrusted repeated ready messages cannot extend the deadline");
  r.message(frame, { id, type: "result", ok: true, output: "42" });
  assert.equal((await result).output, "42");
  assert.equal(frame.removed, true);
  assert.equal(r.listeners.size, 0);
  assert.equal(r.timers.size, 0);
});

test("stop and replacement dispose the old run without accepting late output", async () => {
  const r = runtime();
  const first = r.api.run("js", "while (true) {}");
  await r.flush();
  const old = r.frames[0];
  const second = r.api.run("js", "console.log(1)");
  assert.equal((await first).ok, false);
  assert.equal(old.removed, true);
  await r.flush();
  const current = r.frames[1];
  r.message(old, { id: r.id(old), type: "result", ok: true, output: "late" });
  assert.equal(current.removed, undefined);
  r.api.stop();
  assert.equal((await second).output, "Ausführung gestoppt.");
  assert.equal(r.listeners.size, 0);
});

test("loading failures and execution timeouts finish with a usable error", async () => {
  const failed = runtime({ fail: true });
  assert.match((await failed.api.run("python", "print(1)")).output, /Code-Laufzeit fehlt/);
  assert.equal(failed.listeners.size, 0);
  const r = runtime();
  const result = r.api.run("js", "while (true) {}");
  await r.flush();
  const frame = r.frames[0];
  r.message(frame, { id: r.id(frame), type: "ready" });
  [...r.timers][0].callback();
  assert.match((await result).output, /Zeitlimit nach 8 Sekunden/);
  assert.equal(frame.removed, true);
});

test("both public shells load the isolated runner before the app; parent eval is gone", () => {
  const read = file => fs.readFileSync(path.join(__dirname, "..", file), "utf8");
  for (const file of ["index.html", "studio.html"]) assert(read(file).indexOf('src="code-runner.js') < read(file).indexOf('src="app.js'));
  assert.doesNotMatch(read("app.js"), /new Function\(|py\.runPythonAsync|loadPyodide\(/);
  assert.match(read("app.js"), /PortalCodeRunner\.run\(language, code\)/);
  assert.match(read("app.js"), /PortalCodeRunner\?\.stop\(\)/);
});
