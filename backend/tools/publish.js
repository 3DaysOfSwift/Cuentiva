import { readFile } from 'node:fs/promises';
import { prepare } from '../wix/catalogue.js';
const endpoint = process.env.CUENTIVA_ENDPOINT;
const token = process.env.CUENTIVA_PUBLISH_TOKEN;
if (!endpoint || !token || !(new URL(endpoint).protocol === 'https:' || new URL(endpoint).hostname === '127.0.0.1')) throw Error('Set CUENTIVA_ENDPOINT and CUENTIVA_PUBLISH_TOKEN (never commit the token).');
const source = process.argv[2] || new URL('../../Cuentiva/3 - App Resources/Books.json',import.meta.url);
const {manifest,chunks} = prepare(JSON.parse(await readFile(source,'utf8')));
async function post(query, body) {
  const url = new URL(endpoint); Object.entries(query).forEach(([k,v]) => url.searchParams.set(k,String(v)));
  for (let attempt=0; attempt<4; attempt++) {
    const r = await fetch(url,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'text/plain; charset=utf-8'},body,signal:AbortSignal.timeout(60000)});
    if (r.ok) return;
    if ((r.status === 429 || r.status >= 500) && attempt<3) { await new Promise(r=>setTimeout(r,1000*2**attempt)); continue; }
    throw Error(`Publishing failed (${r.status}): ${await r.text()}`);
  }
}
await post({action:'begin'},JSON.stringify(manifest));
for (let i=0;i<chunks.length;i++) await post({action:'part',version:manifest.version,part:i},chunks[i]);
await post({action:'publish',version:manifest.version},'');
console.log(`Published ${manifest.books} books, ${manifest.bytes} UTF-8 bytes, ${manifest.chunks} parts; release ${manifest.version}`);
