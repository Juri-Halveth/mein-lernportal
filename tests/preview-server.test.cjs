const test = require('node:test');
const assert = require('node:assert/strict');
const {spawn} = require('node:child_process');
const http = require('node:http');
const path = require('node:path');

async function start() {
  const child=spawn(process.execPath,['tools/serve.cjs'],{cwd:path.join(__dirname,'..'),env:{...process.env,PORT:'0'},stdio:['ignore','pipe','pipe']});
  let output='';
  const port=await new Promise((resolve,reject)=>{
    const timeout=setTimeout(()=>{child.kill();reject(new Error('Preview did not start'));},5000);
    child.once('exit',code=>{clearTimeout(timeout);reject(new Error('Preview exited: '+code));});
    child.stdout.on('data',data=>{output+=data;const match=/http:\/\/127\.0\.0\.1:(\d+)\//.exec(output);if(match&&Number(match[1])>0){clearTimeout(timeout);resolve(Number(match[1]));}});
  });
  return {child,port};
}
function request(port,target,headers={},method='GET') {
  return new Promise((resolve,reject)=>{
    const req=http.request({host:'127.0.0.1',port,path:target,headers,method},res=>{const chunks=[];res.on('data',chunk=>chunks.push(chunk));res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,body:Buffer.concat(chunks)}));});
    req.on('error',reject);req.end();
  });
}

test('preview keeps malformed requests and non-public paths inside one healthy loopback process',async()=>{
  const {child,port}=await start();
  try {
    const home=await request(port,'/');
    assert.equal(home.status,200);assert.match(home.body.toString(),/Mein Lernportal/);
    assert.equal(home.headers['x-content-type-options'],'nosniff');
    for(const target of ['/%','/%ZZ','/%E0%A4%A']) assert.equal((await request(port,target)).status,400,target);
    for(const target of ['/.git/HEAD','/.git/config','/package-lock.json','/tools/serve.cjs','/tests/portal.test.cjs','/node_modules/jsdom/package.json','/.env','/%2e%2e%2foutside.txt','/..%5coutside.txt','/index.html%00']) {
      assert.equal((await request(port,target)).status,404,target);
    }
    assert.equal((await request(port,'/',{Host:'untrusted.example'})).status,403);
    assert.equal((await request(port,'/',{},'POST')).status,405);
    assert.equal((await request(port,'/big-bang/')).status,200);
    assert.equal((await request(port,'/ath/')).status,200);
    assert.equal((await request(port,'/languages/catalog.json')).status,200);
    const head=await request(port,'/curriculum.js',{},'HEAD');
    assert.equal(head.status,200);assert.equal(head.body.length,0);
    const gzip=await request(port,'/styles.css',{'Accept-Encoding':'gzip'});
    assert.equal(gzip.headers['content-encoding'],'gzip');
    assert.equal((await request(port,'/')).status,200,'invalid requests leave the server running');
  } finally {
    child.kill();
    if(child.exitCode===null) await new Promise(resolve=>child.once('exit',resolve));
  }
});
