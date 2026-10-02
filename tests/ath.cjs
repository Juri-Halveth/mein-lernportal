'use strict';
const fs=require('node:fs');const path=require('node:path');const assert=require('node:assert/strict');const {JSDOM}=require('jsdom');
const base=process.argv[2]||path.join(__dirname,'../ath');
const html=fs.readFileSync(path.join(base,'index.html'),'utf8');const script=fs.readFileSync(path.join(base,'app.js'),'utf8');
assert(!/LVTH/.test(html+script));assert(!/https?:\/\//.test(script));assert(!/localStorage|fetch\(|XMLHttpRequest/.test(script));
const dom=new JSDOM(html,{runScripts:'outside-only'});dom.window.eval(script);const d=dom.window.document;
for(let i=0;i<3;i++)d.getElementById('transfer').click();assert.equal(d.getElementById('anna').textContent,'1 ATH');assert.equal(d.getElementById('ben').textContent,'9 ATH');
d.getElementById('transfer').click();assert.equal(d.getElementById('anna').textContent,'1 ATH');assert.match(d.getElementById('result').textContent,/weniger/);
d.getElementById('reset').click();assert.equal(d.getElementById('anna').textContent,'10 ATH');assert.equal(d.getElementById('ben').textContent,'0 ATH');
for(const a of d.querySelectorAll('[href]')){const href=a.getAttribute('href');if(href.startsWith('#')&&href.length>1)assert(d.querySelector(href),href);else if(!/^(https?:|\.\.\/|#)/.test(href))assert(fs.existsSync(path.join(base,href)),href);}
const receipt=JSON.parse(fs.readFileSync(path.join(base,'technical-receipt.json'),'utf8'));assert.equal(receipt.unit,'ATH');assert.equal(receipt.v05.passed.length,9);assert.equal(receipt.v05.selftestPassed,14);
assert(!/C:\\\\|private\.dpapi|private\.devnet/.test(JSON.stringify(receipt)));assert.match(fs.readFileSync(path.join(base,'LICENSE.txt'),'utf8'),/ISC License/);
console.log('ATH page PASS: transfer, conservation, insufficient balance, reset, links, receipt and license');
