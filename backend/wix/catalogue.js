import { Buffer } from 'buffer';
// Text-only catalogue release service. No member writes or media endpoints.
import { createHash } from 'crypto';
export const LIMIT = 1024;
export const MAX_BYTES = 1048576;
export const digest = text => createHash('sha256').update(text, 'utf8').digest('hex');
export class Fault extends Error { constructor(status, message) { super(message); this.status = status; } }
const check = (ok, message) => { if (!ok) throw new Fault(400, message); };
const text = x => typeof x === 'string' && x.length > 0;
export function validateBooks(books) {
  check(Array.isArray(books) && books.length > 0 && books.length <= 500, 'Invalid books');
  const keys = new Set('id title englishTitle author level symbol palette summary sentences vocabulary license authorID matchGlossary isDemoLocation submissionLocation format scene continuation verbFocus'.split(' '));
  const ids = new Set();
  for (const b of books) {
    check(b && typeof b === 'object' && Object.keys(b).every(k => keys.has(k)), 'Unsupported book field (text only)');
    check(['id','title','englishTitle','author','level','symbol','summary','license'].every(k => text(b[k])), 'Missing book text');
    check(/^[a-zA-Z0-9_-]{1,80}$/.test(b.id) && !ids.has(b.id), 'Duplicate or invalid book ID'); ids.add(b.id);
    check(['A1','A2','B1','B2','C1','C2'].includes(b.level) && Number.isInteger(b.palette) && b.palette >= 0, 'Invalid book metadata');
    check(b.format == null || ['story','movieScript','verbs'].includes(b.format), 'Invalid format');
    check(Array.isArray(b.sentences) && b.sentences.length && (b.continuation == null || Array.isArray(b.continuation)), 'Invalid sentences');
    const lines = [...b.sentences, ...(b.continuation || [])], lineIDs = new Set();
    check(lines.length <= 1000, 'Book too long');
    for (const s of lines) {
      check(s && Object.keys(s).every(k => ['id','spanish','english','speaker'].includes(k)) && text(s.id) && text(s.spanish) && text(s.english) && (s.speaker == null || text(s.speaker)), 'Invalid sentence');
      check(!lineIDs.has(s.id), 'Duplicate sentence ID'); lineIDs.add(s.id);
    }
    check(Array.isArray(b.vocabulary) && b.vocabulary.every(v => v && Object.keys(v).every(k => ['word','lemma','occurrences'].includes(k)) && text(v.word) && text(v.lemma) && Number.isInteger(v.occurrences) && v.occurrences > 0), 'Invalid vocabulary');
    if (b.authorID != null) check(text(b.authorID), 'Invalid author');
    if (b.matchGlossary != null) check(typeof b.matchGlossary === 'object' && !Array.isArray(b.matchGlossary) && Object.values(b.matchGlossary).every(text), 'Invalid glossary');
    if (b.scene != null) check(text(b.scene), 'Invalid scene');
    if (b.isDemoLocation != null) check(typeof b.isDemoLocation === 'boolean', 'Invalid location flag');
    if (b.submissionLocation != null) {
      const l = b.submissionLocation;
      check(l && Object.keys(l).every(k => ['latitude','longitude','accuracy','placeName','capturedAt'].includes(k)) && Number.isFinite(l.latitude) && Math.abs(l.latitude) <= 90 && Number.isFinite(l.longitude) && Math.abs(l.longitude) <= 180 && text(l.placeName) && Number.isFinite(l.accuracy) && l.accuracy >= 0 && Number.isFinite(l.capturedAt) && b.isDemoLocation === true, 'Only fictional demo locations may be published by this API');
    }
    if (b.verbFocus != null) {
      const v = b.verbFocus;
      check(v && Object.keys(v).every(k => ['infinitive','tense','forms','scope'].includes(k)) && text(v.infinitive) && text(v.tense) && text(v.scope) && Array.isArray(v.forms) && v.forms.every(text), 'Invalid verb focus');
    }
  }
  check(ids.has('cafe'), 'The free introduction must remain available');
  return books;
}
export function prepare(books) {
  validateBooks(books);
  const payload = JSON.stringify(books), bytes = Buffer.byteLength(payload);
  check(bytes <= MAX_BYTES, 'Catalogue too large');
  const chunks = []; let chunk = '', size = 0;
  for (const char of payload) {
    const n = Buffer.byteLength(char);
    if (size + n > LIMIT) { chunks.push(chunk); chunk = ''; size = 0; }
    chunk += char; size += n;
  }
  if (chunk) chunks.push(chunk);
  return { manifest: { schema: 1, version: digest(payload), bytes, chunks: chunks.length, books: books.length }, chunks };
}
export function validateManifest(m) {
  check(m && Object.keys(m).sort().join(',') === 'books,bytes,chunks,schema,version', 'Invalid manifest fields');
  check(m.schema === 1 && /^[a-f0-9]{64}$/.test(m.version), 'Invalid release');
  check(Number.isInteger(m.bytes) && m.bytes > 0 && m.bytes <= MAX_BYTES && Number.isInteger(m.chunks) && m.chunks > 0 && m.chunks <= 1100 && m.bytes <= m.chunks * LIMIT && Number.isInteger(m.books) && m.books > 0 && m.books <= 500, 'Invalid release size');
  return m;
}
export const releaseKey = v => 'r' + v.slice(0, 32);
export const chunkKey = (v, n) => 'c' + v.slice(0, 24) + '-' + String(n).padStart(5, '0');
export function service(store) {
  async function release(v) { check(/^[a-f0-9]{64}$/.test(v || ''), 'Invalid version'); const r = await store.get(releaseKey(v)); if (!r || r.release !== v) throw new Fault(404, 'Release not found'); return r; }
  return {
    async manifest() { const state = await store.get('active'); if (!state) throw new Fault(503, 'Catalogue not published'); const r = await release(state.release); if (!r.ready) throw new Fault(503,'Catalogue not ready'); return JSON.parse(r.payload); },
    async chunk(v, n) { const r = await release(v); if (!r.ready) throw new Fault(404, 'Release not published'); check(Number.isInteger(n) && n >= 0 && n < JSON.parse(r.payload).chunks, 'Invalid part'); const row = await store.get(chunkKey(v,n)); if (!row || row.release !== v) throw new Fault(503, 'Part missing'); return row.payload; },
    async begin(m) { validateManifest(m); await store.insertImmutable({ _id: releaseKey(m.version), kind:'release', release:m.version, payload:JSON.stringify(m), ready:false }); },
    async upload(v, n, payload) { const r = await release(v), m = JSON.parse(r.payload); check(Number.isInteger(n) && n >= 0 && n < m.chunks && typeof payload === 'string' && Buffer.byteLength(payload) > 0 && Buffer.byteLength(payload) <= LIMIT, 'Invalid part'); await store.insertImmutable({_id:chunkKey(v,n),kind:'chunk',release:v,part:n,payload}); },
    async publish(v) {
      const r = await release(v), m = JSON.parse(r.payload), rows = await store.chunks(v);
      check(rows.length === m.chunks, 'Upload incomplete'); rows.sort((a,b) => a.part-b.part);
      check(rows.every((x,i) => x.part === i && Buffer.byteLength(x.payload) <= LIMIT), 'Invalid parts');
      const payload = rows.map(x => x.payload).join('');
      check(Buffer.byteLength(payload) === m.bytes && digest(payload) === v, 'Checksum mismatch');
      let books; try { books = JSON.parse(payload); } catch { throw new Fault(400,'Invalid JSON'); }
      check(validateBooks(books).length === m.books, 'Book count mismatch');
      await store.save({...r,ready:true});
      // Single active pointer is changed only after every immutable part is verified.
      await store.save({_id:'active',kind:'active',release:v,payload:''});
      return m;
    }
  };
}
