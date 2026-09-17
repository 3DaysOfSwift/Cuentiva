import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {prepare, service, Fault, LIMIT, validateBooks} from '../wix/catalogue.js';
const books=JSON.parse(await readFile(new URL('../../Cuentiva/3 - App Resources/Books.json',import.meta.url),'utf8'));
function fixture(){const rows=new Map();return service({async get(id){return rows.get(id)},async save(x){rows.set(x._id,{...x})},async insertImmutable(x){const old=rows.get(x._id);if(old&&old.payload!==x.payload)throw new Fault(409,'Conflict');if(!old)rows.set(x._id,{...x})},async chunks(v){return [...rows.values()].filter(x=>x.kind==='chunk'&&x.release===v)}})}
test('real catalogue round trips in UTF-8 text parts below 1KiB',async()=>{
 const {manifest,chunks}=prepare(books),api=fixture();
 assert.ok(chunks.every(c=>Buffer.byteLength(c)<=LIMIT));
 await api.begin(manifest); await api.begin(manifest);
 await assert.rejects(()=>api.chunk(manifest.version,0));
 for(let i=0;i<chunks.length;i++){await api.upload(manifest.version,i,chunks[i]); await api.upload(manifest.version,i,chunks[i]);}
 await api.publish(manifest.version);assert.deepEqual(await api.manifest(),manifest);
 let downloaded='';for(let i=0;i<chunks.length;i++)downloaded+=await api.chunk(manifest.version,i);
 assert.deepEqual(JSON.parse(downloaded),books);
 await assert.rejects(()=>api.upload(manifest.version,0,'tampered'));
});
test('incomplete and corrupt releases never replace active catalogue',async()=>{
 const api=fixture(),a=prepare(books.slice(0,1));await api.begin(a.manifest);for(let i=0;i<a.chunks.length;i++)await api.upload(a.manifest.version,i,a.chunks[i]);await api.publish(a.manifest.version);
 const b=prepare(books);await api.begin(b.manifest);await api.upload(b.manifest.version,0,b.chunks[0]);await assert.rejects(()=>api.publish(b.manifest.version));assert.deepEqual(await api.manifest(),a.manifest);
 await assert.rejects(()=>api.upload(b.manifest.version,1,'x'.repeat(1025)));
});
test('reject media fields and duplicates',()=>{
 assert.throws(()=>validateBooks([{...books[0],image:'data:image/png;base64,xx'}]));
 assert.throws(()=>validateBooks([books[0],books[0]]));
 assert.throws(()=>prepare([{...books[0],sentences:[]}]))
});
