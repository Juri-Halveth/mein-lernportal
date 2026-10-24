'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');
const root = path.join(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');

function boot(kind) {
  const dom = new JSDOM('<!doctype html><html><body><div id="app"></div></body></html>', {
    url: 'https://portal.invalid/#lesson/qa-lifecycle', runScripts: 'outside-only', pretendToBeVisual: true
  });
  const w = dom.window;
  w.scrollTo = () => {};
  w.HTMLElement.prototype.scrollIntoView = () => {};
  w.structuredClone = value => w.JSON.parse(w.JSON.stringify(value));
  w.matchMedia = () => ({ matches: true, addEventListener() {}, removeEventListener() {} });
  const pending = [];
  let stops = 0;
  w.PortalCodeRunner = { stop() { stops++; }, run(language, code) {
    return new Promise(resolve => pending.push({ language, code, resolve }));
  } };
  w.eval(read('curriculum.js'));
  w.CURRICULUM.tracks[0].stages[0].lessons.unshift({ id: 'qa-lifecycle', title: 'Runtime lifecycle fixture', type: 'lesson', minutes: 1,
    beats: [{ kind: 'text', html: '<p>Start</p>' }, { kind, lang: 'js', code: 'console.log("EXPECTED")', erwartet: 'EXPECTED', erklaerung: 'SYNTHETIC', html: '<p>Controlled delayed result</p>' }, { kind: 'text', html: '<p>Finish</p>' }] });
  for (const file of ['learning-profile.js', 'reference.js', 'basics.js', 'plotter.js', 'payment-simulator.js', 'app.js']) w.eval(read(file));
  return { dom, w, pending, stops: () => stops };
}

for (const kind of ['verify', 'xray']) test(kind + ': a delayed result cannot unlock a freshly rendered step after back/forward', async () => {
  const f = boot(kind);
  const doc = f.w.document;
  try {
    doc.querySelector('.beat-weiter').click();
    function start() {
      if (kind === 'verify') doc.querySelector('[data-bet="ok"]').click();
      doc.querySelector(kind === 'verify' ? '.act-verify' : '.act-xray').click();
    }
    start();
    assert.equal(f.pending.length, 1);
    const stops = f.stops();
    doc.querySelector('.beat-zurueck').click();
    doc.querySelector('.beat-weiter').click();
    assert(f.stops() >= stops + 2, 'each internal stage replacement stops the previous runtime');
    assert.equal(doc.querySelector('.beat-weiter').hidden, true);
    f.pending[0].resolve({ ok: true, output: 'EXPECTED' });
    await new Promise(setImmediate);
    assert.equal(doc.querySelector('.beat-weiter').hidden, true, 'stale result must not open the new step');
    assert.equal(doc.querySelector(kind === 'verify' ? '.verify-reveal' : '.xray-out').textContent, '');
    start();
    f.pending[1].resolve({ ok: true, output: 'EXPECTED' });
    await new Promise(setImmediate);
    assert.equal(doc.querySelector('.beat-weiter').hidden, false, 'a current result still opens its own step');
  } finally { f.dom.window.close(); }
});
