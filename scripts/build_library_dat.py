#!/usr/bin/env python3
"""Compile the reviewed JSON source into indexed UTF-8 binary assets (no runtime JSON)."""
import argparse
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / 'Cuentiva/3 - App Resources'
NONE = 0xffffffff
STRINGS = ['id', 'title', 'englishTitle', 'author', 'level', 'symbol', 'summary', 'license', 'authorID', 'format', 'scene']
FIELDS = set(STRINGS + ['palette', 'isDemoLocation', 'sentences', 'vocabulary', 'continuation', 'matchGlossary', 'verbFocus', 'submissionLocation', 'personalAuthor'])

class Builder:
    def __init__(self, books):
        self.data = bytearray(b'CUENLIB\x00' + struct.pack('<II', 1, len(books)))
        self.data.extend(bytes(140 * len(books)))
        self.strings = {}
        for i, book in enumerate(books):
            if set(book) - FIELDS:
                raise ValueError(f'Unsupported fields: {set(book) - FIELDS}')
            record = b''.join(self.string(book.get(k)) for k in STRINGS)
            record += struct.pack('<II', book['palette'], 2 if book.get('isDemoLocation') is None else int(book['isDemoLocation']))
            record += self.table(book['sentences'], self.sentence)
            record += self.table(book['vocabulary'], self.vocabulary)
            record += self.table(book.get('continuation'), self.sentence)
            glossary = book.get('matchGlossary')
            record += self.table(None if glossary is None else sorted(glossary.items()), lambda kv: self.string(kv[0]) + self.string(kv[1]))
            record += self.optional_record(book.get('verbFocus'), self.verb)
            record += self.optional_record(book.get('submissionLocation'), self.location)
            record += self.optional_record(book.get('personalAuthor'), self.author)
            assert len(record) == 140
            self.data[16 + 140*i:16 + 140*(i+1)] = record

    def append(self, data):
        offset = len(self.data)
        if offset + len(data) >= NONE: raise ValueError('Library exceeds 32-bit offsets')
        self.data.extend(data)
        return offset

    def string(self, value):
        if value is None: return struct.pack('<II', NONE, 0)
        if value not in self.strings:
            raw = value.encode('utf-8')
            self.strings[value] = (self.append(raw), len(raw))
        return struct.pack('<II', *self.strings[value])

    def table(self, values, encode):
        if values is None: return struct.pack('<II', NONE, 0)
        raw = b''.join(encode(v) for v in values)
        return struct.pack('<II', self.append(raw), len(values))

    def optional_record(self, value, encode):
        return struct.pack('<I', NONE if value is None else self.append(encode(value)))

    def sentence(self, s):
        if set(s) - {'id', 'spanish', 'english', 'speaker'}: raise ValueError('Unknown sentence field')
        return b''.join(self.string(s.get(k)) for k in ['id', 'spanish', 'english', 'speaker'])

    def vocabulary(self, v):
        if set(v) != {'word', 'lemma', 'occurrences'}: raise ValueError('Unknown vocabulary fields')
        return self.string(v['word']) + self.string(v['lemma']) + struct.pack('<I', v['occurrences'])

    def verb(self, v):
        if set(v) != {'infinitive', 'tense', 'scope', 'forms'}: raise ValueError('Unknown verb fields')
        return b''.join(self.string(v[k]) for k in ['infinitive', 'tense', 'scope']) + self.table(v['forms'], self.string)

    def location(self, v):
        if set(v) != {'latitude', 'longitude', 'accuracy', 'capturedAt', 'placeName'}: raise ValueError('Unknown location fields')
        return struct.pack('<dddd', *(v[k] for k in ['latitude', 'longitude', 'accuracy', 'capturedAt'])) + self.string(v['placeName'])

    def author(self, v):
        if set(v) != {'id', 'name', 'portrait', 'introduction', 'note'}: raise ValueError('Unknown author fields')
        return b''.join(self.string(v[k]) for k in ['id', 'name', 'portrait', 'introduction', 'note'])

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true', help='Fail if committed assets are stale')
    parser.add_argument('--output-dir', type=Path, default=RESOURCES)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    books = json.loads((RESOURCES / 'Books.json').read_text())
    if len({b['id'] for b in books}) != len(books): raise ValueError('Duplicate book IDs')
    intro = [b for b in books if b['id'] == 'cafe']
    if len(intro) != 1: raise ValueError('Exactly one cafe onboarding book is required')
    for name, values in [('Library.dat', books), ('Introduction.dat', intro)]:
        data = bytes(Builder(values).data)
        path = args.output_dir / name
        if args.check:
            if not path.exists() or path.read_bytes() != data: raise SystemExit(f'{name} is stale; run scripts/build_library_dat.py')
        else: path.write_bytes(data)
        print(f'{name}: {len(values)} books, {len(data):,} bytes')

if __name__ == '__main__': main()
