const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const vm = require("node:vm");
const { JSDOM, ResourceLoader, VirtualConsole } = require("jsdom");

const root = path.resolve(__dirname, "..");
const read = name => fs.readFileSync(path.join(root, name), "utf8");
const bytes = name => fs.readFileSync(path.join(root, name));

function loadClassic(files) {
  const context = { window: {}, console, structuredClone, crypto: globalThis.crypto };
  vm.createContext(context);
  for (const file of files) vm.runInContext(read(file), context, { filename: file });
  return context.window;
}

function contentContract() {
  const window = loadClassic(["curriculum.js"]);
  const tracks = window.CURRICULUM.tracks;
  const stages = tracks.flatMap(track => track.stages);
  const lessons = stages.flatMap(stage => stage.lessons);
  const ids = lessons.map(lesson => lesson.id);
  assert.equal(tracks.length, 13, "expected 13 topics");
  assert.equal(stages.length, 133, "expected 133 stages");
  assert.equal(lessons.length, 702, "expected 702 lessons");
  assert.equal(new Set(ids).size, 702, "every lesson id must be unique");
  assert(ids.includes("ki-2-4"), "direct-link reference lesson is missing");
  assert.equal(crypto.createHash("sha256").update(bytes("curriculum.js")).digest("hex"), "50775f64d82c0dd77ec2db4a9e0f6a3ab8714ff8cb55eba429fb7d9fa8c14f04", "curriculum snapshot changed without updating its bound digest");
}

function shellContract() {
  for (const file of ["index.html", "studio.html"]) {
    const html = read(file);
    assert.match(html, /id="app"/);
    assert.match(html, /app\.js\?v=/);
    assert.match(html, /curriculum\.js\?v=/);
    assert.doesNotMatch(html, /account-auth\.js|account-progress\.js|stripe|checkout|type="password"|>\s*Anmelden\s*</i, `${file} contains an access gate`);
    const executableResources = [
      ...[...html.matchAll(/<script[^>]+src="([^"]+)"/g)].map(match => match[1]),
      ...[...html.matchAll(/<link[^>]+rel="(?:stylesheet|icon|apple-touch-icon|manifest)"[^>]+href="([^"]+)"/g)].map(match => match[1])
    ];
    assert(executableResources.every(value => !/^https?:/i.test(value)), `${file} loads a third-party startup resource`);
  }
  const app = read("app.js");
  assert.doesNotMatch(app, /LearningAccount|LSAccountProgress|renderLogin|renderRegister/);
  assert.match(app, /id: "ki"/);
  assert.match(app, /Public startup: no account, payment or wallet request/);
}

function localProfileContract() {
  const window = loadClassic(["curriculum.js", "learning-profile.js"]);
  const data = new Map();
  const storage = { getItem:key => data.has(key) ? data.get(key) : null, setItem:(key,value) => data.set(key,String(value)) };
  const store = window.LearningProfile.createStore(storage, window.CURRICULUM);
  const state = store.read();
  state.name = "Teststern";
  state.done["ki-2-4"] = true;
  store.write(state);
  const reloaded = window.LearningProfile.createStore(storage, window.CURRICULUM).read();
  assert.equal(reloaded.name, "Teststern");
  assert.equal(reloaded.done["ki-2-4"], true);
  assert.equal(store.lessonCount, 702);
}

const mime = { ".html":"text/html; charset=utf-8", ".js":"text/javascript; charset=utf-8", ".css":"text/css; charset=utf-8", ".json":"application/json", ".webmanifest":"application/manifest+json", ".png":"image/png", ".ico":"image/x-icon", ".svg":"image/svg+xml" };
function server() {
  const requests = [];
  const instance = http.createServer((req,res) => {
    requests.push(req.url);
    let pathname = decodeURIComponent(new URL(req.url,"http://127.0.0.1").pathname);
    pathname = pathname.replace(/^\/mein-lernportal\/?/, "/");
    const relative = pathname === "/" ? "index.html" : pathname.replace(/^\/+/, "");
    const target = path.resolve(root,relative);
    if (!target.startsWith(root + path.sep) || !fs.existsSync(target) || fs.statSync(target).isDirectory()) { res.writeHead(404); res.end("missing"); return; }
    res.writeHead(200,{"content-type":mime[path.extname(target).toLowerCase()] || "application/octet-stream","cache-control":"no-store"});
    fs.createReadStream(target).pipe(res);
  });
  return new Promise(resolve => instance.listen(0,"127.0.0.1",() => resolve({ instance, requests, port:instance.address().port })));
}

class OwnResourceLoader extends ResourceLoader {
  constructor(origin) { super(); this.origin = origin; this.seen = []; }
  fetch(url, options) {
    this.seen.push(url);
    assert(url.startsWith(this.origin), `unexpected startup request: ${url}`);
    return super.fetch(url, options);
  }
}

async function waitFor(test, label, timeout = 12000) {
  const start = Date.now();
  while (Date.now() - start < timeout) {
    if (test()) return;
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  throw new Error(`timeout: ${label}`);
}

async function browserDomContract() {
  const { instance, requests, port } = await server();
  const origin = `http://127.0.0.1:${port}`;
  const loader = new OwnResourceLoader(origin);
  const errors = [];
  const virtualConsole = new VirtualConsole();
  virtualConsole.on("jsdomError", error => errors.push(error.message));
  try {
    const dom = await JSDOM.fromURL(`${origin}/mein-lernportal/`, {
      runScripts:"dangerously", resources:loader, pretendToBeVisual:true, virtualConsole,
      beforeParse(window) { window.scrollTo = () => {}; window.structuredClone = structuredClone; }
    });
    await waitFor(() => dom.window.document.querySelectorAll(".world-card").length === 13, "home catalogue");
    const document = dom.window.document;
    assert.equal(document.querySelectorAll(".world-card").length, 13);
    assert.match(document.querySelector(".portal-hero h1").textContent, /Öffnen\.Suchen\.Lernen\./);
    assert.equal(document.querySelectorAll('input[type="password"], form[action], [data-paywall]').length, 0);
    assert(!/Anmelden|Registrieren|Kaufen/.test(document.body.textContent), "home renders an account or purchase prompt");
    const input = document.getElementById("lessonSearch");
    input.value = "Plus Codes";
    input.dispatchEvent(new dom.window.Event("input",{bubbles:true}));
    assert(document.querySelectorAll(".lesson-result").length >= 1, "lesson-title search failed");
    dom.window.location.hash = "#lesson/ki-2-4";
    await waitFor(() => /Plus Codes/.test(document.querySelector("#main-content")?.textContent || ""), "direct lesson route");
    assert.equal(loader.seen.filter(url => !url.startsWith(origin)).length, 0);
    assert(requests.some(url => url.includes("curriculum.js")));
    assert.equal(errors.filter(message => !/Could not parse CSS stylesheet/.test(message)).length, 0, errors.join("\n"));
    dom.window.close();
  } finally {
    await new Promise(resolve => instance.close(resolve));
  }
}

(async () => {
  contentContract();
  shellContract();
  localProfileContract();
  await browserDomContract();
  console.log("PASS mein-lernportal: 13 tracks, 133 stages, 702 unique lessons; open shell and local progress verified");
})().catch(error => { console.error(error); process.exitCode = 1; });
