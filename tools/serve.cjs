const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const zlib = require("node:zlib");

const root = path.resolve(__dirname, "..");
const port = Number(process.env.PORT || 4175);
const mime = { ".html":"text/html; charset=utf-8", ".js":"text/javascript; charset=utf-8", ".css":"text/css; charset=utf-8", ".json":"application/json; charset=utf-8", ".webmanifest":"application/manifest+json; charset=utf-8", ".png":"image/png", ".ico":"image/x-icon", ".svg":"image/svg+xml", ".txt":"text/plain; charset=utf-8", ".xml":"application/xml; charset=utf-8" };

const server = http.createServer((req, res) => {
  const pathname = decodeURIComponent(new URL(req.url, `http://${req.headers.host}`).pathname);
  const relative = pathname === "/" ? "index.html" : pathname.replace(/^\/+/, "");
  const target = path.resolve(root, relative);
  if (!target.startsWith(root + path.sep) || !fs.existsSync(target) || fs.statSync(target).isDirectory()) {
    res.writeHead(404, { "content-type": "text/plain; charset=utf-8" }); res.end("Nicht gefunden"); return;
  }
  const type = mime[path.extname(target).toLowerCase()] || "application/octet-stream";
  const compress = /^(?:text\/|application\/(?:json|javascript|xml|manifest\+json))/.test(type) && /\bgzip\b/.test(req.headers["accept-encoding"] || "");
  res.writeHead(200, { "content-type": type, "cache-control": "no-store", ...(compress ? { "content-encoding":"gzip", "vary":"accept-encoding" } : {}) });
  const stream = fs.createReadStream(target);
  if (compress) stream.pipe(zlib.createGzip({ level: 6 })).pipe(res); else stream.pipe(res);
});
server.listen(port, "127.0.0.1", () => console.log(`Mein Lernportal: http://127.0.0.1:${port}/`));
