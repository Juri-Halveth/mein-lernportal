/* Disposable exercise runtime. The opaque iframe owns the worker, not the portal. */
(function (root) {
  "use strict";
  const workerURL = new URL("code-worker.js", document.currentScript.src);
  let workerSource;
  let cancelActive;
  function stop() { if (cancelActive) cancelActive(); }
  async function run(language, code) {
    stop();
    if (!["js", "python"].includes(language) || typeof code !== "string" || code.length > 50000) {
      return { ok: false, output: "Ungültiges Programm (maximal 50.000 Zeichen)." };
    }
    return new Promise(resolve => {
      const frame = document.createElement("iframe");
      frame.hidden = true;
      frame.title = "Isolierte Codeausführung";
      frame.setAttribute("sandbox", "allow-scripts");
      const id = crypto.randomUUID();
      let timer;
      let ended = false;
      let started = false;
      function finish(result) {
        if (ended) return;
        ended = true;
        clearTimeout(timer);
        root.removeEventListener("message", receive);
        frame.remove();
        if (cancelActive === cancel) cancelActive = null;
        resolve(result);
      }
      function cancel() { finish({ ok: false, output: "Ausführung gestoppt." }); }
      function receive(event) {
        if (event.source !== frame.contentWindow || event.data?.id !== id) return;
        if (event.data.type === "ready" && !started) {
          started = true;
          clearTimeout(timer);
          timer = setTimeout(() => finish({ ok: false, output: "Zeitlimit nach 8 Sekunden. Prüfe Schleifen und Abbruchbedingungen." }), 8000);
        } else if (event.data.type === "result") {
          finish({ ok: event.data.ok === true, output: String(event.data.output).slice(0, 34000) });
        }
      }
      cancelActive = cancel;
      root.addEventListener("message", receive);
      timer = setTimeout(() => finish({ ok: false, output: "Die Code-Laufzeit konnte nicht rechtzeitig geladen werden." }), 90000);
      (async () => {
        try {
          if (!workerSource) {
            const response = await fetch(workerURL);
            if (!response.ok) throw new Error("Code-Laufzeit fehlt.");
            workerSource = await response.text();
          }
          if (ended) return;
          const data = JSON.stringify({ id, source: workerSource, language, code }).replace(/</g, "\\u003c");
          const csp = "default-src 'none'; script-src 'unsafe-inline' 'unsafe-eval' https://cdn.jsdelivr.net/pyodide/v0.26.2/full/; worker-src blob:; connect-src https://cdn.jsdelivr.net/pyodide/v0.26.2/full/; base-uri 'none'; form-action 'none'";
          frame.srcdoc = '<!doctype html><meta http-equiv="Content-Security-Policy" content="' + csp + '"><script>const data=' + data + ';const worker=new Worker(URL.createObjectURL(new Blob([data.source],{type:"text/javascript"})));worker.onmessage=event=>parent.postMessage({...event.data,id:data.id},"*");worker.onerror=()=>parent.postMessage({id:data.id,type:"result",ok:false,output:"Laufzeit nicht verfügbar."},"*");worker.postMessage({language:data.language,code:data.code});<\/script>';
          document.body.append(frame);
        } catch (error) {
          finish({ ok: false, output: "Start fehlgeschlagen: " + error.message });
        }
      })();
    });
  }
  root.PortalCodeRunner = Object.freeze({ run, stop });
})(window);
