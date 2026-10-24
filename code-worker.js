"use strict";
// Its creator is an opaque-origin sandbox; the worker inherits that CSP.
self.onmessage = async ({ data }) => {
  const logs = [];
  let size = 0;
  function output(...values) {
    if (size >= 32000) return;
    const line = values.map(value => {
      if (typeof value === "string") return value;
      try { return JSON.stringify(value) ?? String(value); } catch { return String(value); }
    }).join(" ");
    const bounded = line.slice(0, 32000 - size);
    logs.push(bounded);
    size += bounded.length + 1;
  }
  try {
    if (data.language === "python") {
      const base = "https://cdn.jsdelivr.net/pyodide/v0.26.2/full/";
      importScripts(base + "pyodide.js");
      const python = await loadPyodide({ indexURL: base });
      python.setStdout({ batched: output });
      python.setStderr({ batched: output });
      self.postMessage({ type: "ready" });
      await python.runPythonAsync(data.code);
    } else {
      self.postMessage({ type: "ready" });
      const console = { log: output, info: output, warn: output, error: output };
      await new Function("console", '"use strict";\n' + data.code)(console);
      for (let index = 0; index < 4; index++) await new Promise(resolve => setTimeout(resolve, 0));
    }
    self.postMessage({ type: "result", ok: true, output: logs.join("\n") });
  } catch (error) {
    output("⚠ Fehler: " + String(error.message || error).slice(-2000));
    self.postMessage({ type: "result", ok: false, output: logs.join("\n") });
  }
};
