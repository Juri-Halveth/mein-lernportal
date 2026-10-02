/* SPDX-License-Identifier: ISC */
'use strict';
let anna=100000,ben=0;
const a=document.getElementById('anna'),b=document.getElementById('ben'),message=document.getElementById('result');
function units(n){return new Intl.NumberFormat('de-DE',{maximumFractionDigits:4}).format(n/10000)+' ATH';}
function render(){a.textContent=units(anna);b.textContent=units(ben);}
document.getElementById('transfer').addEventListener('click',()=>{if(anna<30000){message.textContent='Anna hat weniger als 3 ATH. Setze das Beispiel zurück.';return;}anna-=30000;ben+=30000;render();message.textContent='Beispielbuchung: 3 ATH übertragen. Insgesamt bleiben es '+units(anna+ben)+'.';});
document.getElementById('reset').addEventListener('click',()=>{anna=100000;ben=0;render();message.textContent='Zurückgesetzt: Anna hat 10 ATH, Ben hat 0 ATH.';});
