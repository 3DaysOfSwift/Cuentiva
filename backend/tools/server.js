// Local integration server. Never expose this development server to the Internet.
import http from 'node:http';
import { service, Fault, LIMIT } from '../wix/catalogue.js';
const rows = new Map();
export const memoryStore = {
  async get(id) { return rows.get(id); },
  async save(item) { rows.set(item._id,structuredClone(item)); },
  async insertImmutable(item) { const old=rows.get(item._id); if(old && (old.release!==item.release || old.payload!==item.payload)) throw new Fault(409,'Immutable part conflict'); if(!old) rows.set(item._id,structuredClone(item)); },
  async chunks(v) { return [...rows.values()].filter(x=>x.kind==='chunk' && x.release===v); }
};
const api=service(memoryStore);
const token=process.env.CUENTIVA_PUBLISH_TOKEN;
if (!token || token.length<32) throw Error('Set a temporary CUENTIVA_PUBLISH_TOKEN of at least 32 characters.');
http.createServer(async(req,res)=>{
  const reply=(status,body,raw=false)=>{res.writeHead(status,{'Content-Type':raw?'text/plain; charset=utf-8':'application/json','Cache-Control':'no-store'});res.end(raw?body:JSON.stringify(body));};
  try {
    const q=new URL(req.url,'http://127.0.0.1').searchParams;
    if (req.method==='GET') { if(q.has('version')) reply(200,await api.chunk(q.get('version'),Number(q.get('part'))),true); else reply(200,await api.manifest()); return; }
    if(req.method!=='POST') throw new Fault(405,'Method not allowed');
    if(req.headers.authorization!==`Bearer ${token}`) throw new Fault(401,'Unauthorized');
    const parts=[]; let size=0; for await(const part of req) { size+=part.length; if(size>LIMIT) throw new Fault(413,'Too large'); parts.push(part); } const body=Buffer.concat(parts).toString('utf8');
    switch(q.get('action')) {
      case 'begin':await api.begin(JSON.parse(body));break;
      case 'part':await api.upload(q.get('version'),Number(q.get('part')),body);break;
      case 'publish':await api.publish(q.get('version'));break;
      default:throw new Fault(400,'Invalid action');
    }
    reply(200,{ok:true});
  } catch(e) {reply(e.status||500,{error:e.message});}
}).listen(8787,'127.0.0.1',()=>console.log('Cuentiva development API: http://127.0.0.1:8787'));
