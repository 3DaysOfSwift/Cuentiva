import test from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {randomBytes} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {prepare} from '../wix/catalogue.js';
test('HTTP upload, authorization, publication and complete download',async()=>{
 const token=randomBytes(32).toString('hex');
 const child=spawn(process.execPath,['backend/tools/server.js'],{cwd:new URL('../../',import.meta.url),env:{...process.env,CUENTIVA_PUBLISH_TOKEN:token},stdio:['ignore','pipe','pipe']});
 let errors=''; child.stderr.on('data', data => { errors += data.toString(); });
 try {
  await new Promise((resolve,reject)=>{ const timer=setTimeout(()=>reject(Error('Server timeout')),5000);child.stdout.once('data',()=>{clearTimeout(timer);resolve()});child.once('exit',()=>{clearTimeout(timer);reject(Error('Server exited: '+errors))}); });
  const root='http://127.0.0.1:8787';
  assert.equal((await fetch(root,{method:'POST',body:'{}'})).status,401);
  assert.equal((await fetch(root,{method:'POST',headers:{Authorization:`Bearer ${token}`},body:'x'.repeat(1025)})).status,413);
  const books=JSON.parse(await readFile(new URL('../../Cuentiva/3 - App Resources/Books.json',import.meta.url),'utf8'));
  const release=prepare(books);
  async function post(q,body){const r=await fetch(root+'?'+new URLSearchParams(q),{method:'POST',headers:{Authorization:`Bearer ${token}`},body});assert.equal(r.status,200,await r.text());}
  await post({action:'begin'},JSON.stringify(release.manifest));
  for(let i=0;i<release.chunks.length;i++) await post({action:'part',version:release.manifest.version,part:String(i)},release.chunks[i]);
  await post({action:'publish',version:release.manifest.version},'');
  const manifest=await(await fetch(root)).json();assert.deepEqual(manifest,release.manifest);
  let payload='';for(let i=0;i<manifest.chunks;i++){const text=await(await fetch(root+'?'+new URLSearchParams({version:manifest.version,part:String(i)}))).text();assert.ok(Buffer.byteLength(text)<=1024);payload+=text;}
  assert.deepEqual(JSON.parse(payload),books);
 } finally {child.kill();}
});
