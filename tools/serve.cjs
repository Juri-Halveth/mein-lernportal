const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const zlib = require("node:zlib");
const { pipeline } = require("node:stream");

const root = path.resolve(__dirname, "..");
const port = Number(process.env.PORT || 4175);
const allowed = new Set(require("./public-files.cjs"));
const realRoot = fs.realpathSync(root);
const mime = { ".html":"text/html; charset=utf-8", ".js":"text/javascript; charset=utf-8", ".css":"text/css; charset=utf-8", ".json":"application/json; charset=utf-8", ".webmanifest":"application/manifest+json; charset=utf-8", ".png":"image/png", ".ico":"image/x-icon", ".svg":"image/svg+xml", ".txt":"text/plain; charset=utf-8", ".xml":"application/xml; charset=utf-8" };

const server = http.createServer((req, res) => {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Cache-Control", "no-store");
  if (!/^(?:localhost|127\.0\.0\.1)(?::\d{1,5})?$/i.test(req.headers.host || "")) {
    res.writeHead(403).end("Lokale Vorschau"); return;
  }
  if (!["GET", "HEAD"].includes(req.method)) {
    res.writeHead(405, { Allow: "GET, HEAD" }).end(); return;
  }
  let pathname;
  try { pathname = decodeURIComponent(new URL(req.url, "http://localhost").pathname); }
  catch { res.writeHead(400).end("Ungültiger Pfad"); return; }
  let relative = pathname === "/" ? "index.html" : pathname.replace(/^\/+/, "");
  if (relative.endsWith("/")) relative += "index.html";
  if (!allowed.has(relative)) { res.writeHead(404).end("Nicht gefunden"); return; }
  const target = path.resolve(root, relative);
  let realTarget;
  let regularPublicFile;
  try {
    realTarget = fs.realpathSync(target);
    regularPublicFile = realTarget.startsWith(realRoot + path.sep) && fs.statSync(realTarget).isFile();
  }
  catch { res.writeHead(404).end("Nicht gefunden"); return; }
  if (!regularPublicFile) {
    res.writeHead(404, { "content-type": "text/plain; charset=utf-8" }); res.end("Nicht gefunden"); return;
  }
  const type = mime[path.extname(target).toLowerCase()] || "application/octet-stream";
  const compress = /^(?:text\/|application\/(?:json|javascript|xml|manifest\+json))/.test(type) && /\bgzip\b/.test(req.headers["accept-encoding"] || "");
  res.writeHead(200, { "content-type": type, "cache-control": "no-store", ...(compress ? { "content-encoding":"gzip", "vary":"accept-encoding" } : {}) });
  if (req.method === "HEAD") { res.end(); return; }
  const stream = fs.createReadStream(realTarget);
  const streams = compress ? [stream, zlib.createGzip({ level: 6 }), res] : [stream, res];
  pipeline(...streams, error => { if (error) res.destroy(); });
});
server.listen(port, "127.0.0.1", () => console.log(`Mein Lernportal: http://127.0.0.1:${server.address().port}/`));
