import { Buffer } from 'buffer';
import { response } from 'wix-http-functions';
import wixData from 'wix-data';
import { secrets } from 'wix-secrets-backend.v2';
import { elevate } from 'wix-auth';
import { timingSafeEqual } from 'crypto';
import { service, Fault, LIMIT } from 'backend/catalogue';
const COLLECTION = 'CuentivaCatalogue';
const options = { suppressAuth:true, consistentRead:true };
async function get(id) {
  const result = await wixData.query(COLLECTION).eq('_id',id).limit(1).find(options);
  return result.items[0];
}
const api = service({
  get,
  save: item => wixData.save(COLLECTION,item,{suppressAuth:true}),
  async insertImmutable(item) {
    // Insert prevents simultaneous writers from changing an existing chunk.
    try { await wixData.insert(COLLECTION,item,{suppressAuth:true}); }
    catch (error) {
      const old = await get(item._id);
      if (!old || old.release !== item.release || old.payload !== item.payload) throw error;
    }
  },
  async chunks(version) {
    let result = await wixData.query(COLLECTION).eq('kind','chunk').eq('release',version).limit(1000).find(options);
    const items = [...result.items];
    while (result.hasNext()) { result = await result.next(); items.push(...result.items); }
    return items;
  }
});
function reply(status, data, raw = false) {
  const body = raw ? data : JSON.stringify(data);
  if (Buffer.byteLength(body,'utf8') > LIMIT) return response({status:500,body:'{"error":"Response too large"}'});
  return response({status,headers:{'Content-Type':raw?'text/plain; charset=utf-8':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'},body});
}
async function run(action) {
  try { return await action(); }
  catch (e) { return reply(e instanceof Fault ? e.status : 503, {error:e instanceof Fault ? e.message : 'Service temporarily unavailable'}); }
}
export function get_cuentivaCatalogue(request) {
  return run(async () => {
    const q = request.query || {};
    if (q.version !== undefined) {
      if (!/^\d{1,4}$/.test(q.part || '')) throw new Fault(400,'Invalid part');
      return reply(200, await api.chunk(q.version,Number(q.part)),true);
    }
    return reply(200,await api.manifest());
  });
}
// Administrator publishing only. This key must NEVER be shipped in the iOS app.
// Future member submissions require a separate authenticated, moderated workflow.
export function post_cuentivaCatalogue(request) {
  return run(async () => {
    const header = request.headers.authorization || request.headers.Authorization || '';
    if (!header.startsWith('Bearer ') || header.length > 200) throw new Fault(401,'Unauthorized');
    const {value} = await elevate(secrets.getSecretValue)('CUENTIVA_PUBLISH_TOKEN');
    const supplied = Buffer.from(header.slice(7)), expected = Buffer.from(value || '');
    if (expected.length < 32 || supplied.length !== expected.length || !timingSafeEqual(supplied,expected)) throw new Fault(401,'Unauthorized');
    const body = await request.body.text();
    if (Buffer.byteLength(body,'utf8') > LIMIT) throw new Fault(413,'Maximum body is 1024 bytes');
    const q = request.query || {};
    if (q.action === 'begin') { let m; try { m=JSON.parse(body); } catch { throw new Fault(400,'Invalid JSON'); } await api.begin(m); }
    else if (q.action === 'part') { if (!/^\d{1,4}$/.test(q.part || '')) throw new Fault(400,'Invalid part'); await api.upload(q.version,Number(q.part),body); }
    else if (q.action === 'publish') { await api.publish(q.version); }
    else throw new Fault(400,'Unknown action');
    return reply(200,{ok:true});
  });
}
