#!/usr/bin/env python3
"""Build Books.json from the bilingual, three-chapter editorial manuscripts.

Chapter three is stored as `ending`; vocabulary/glossaries cover all three chapters
exposed by Book.fullText. Run build_library_dat.py after this command.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'content/editorial'
OUTPUT = ROOT / 'Cuentiva/3 - App Resources/Books.json'
AUTHORS = {'Pipa': 'marta', 'Brasa': 'ana', 'Musgo': 'luis',
           'Zumi': 'credit-fade9533cfe2', 'Luma': 'credit-53e13e40b11a',
           'Nube': 'credit-5b644d127a59', 'Tilo': 'credit-4ffea73372fb',
           'Mora': 'credit-0047224f3651', 'Faro': 'credit-5f7d24711b1b'}
SYMBOLS = dict(zip(
    'cafe garden train sea repair repair-hour loan-notebook small-guide three-paths three-envelopes rainy-roof patient-investor first-stitch different-door empty-wallet shared-table honest-change sunday-pot film-conversation beans-question first-invitation thoughtful-yes enough-on-paper useful-service travelling-seed tomato-question garden-colours potato-basket two-carrots body-care water-toast pause-before-plan ten-pages metaphor-not-law world-in-backpack brand-from-within four-years-road calendar-of-later cow-two-names cube-among-stars feet-on-earth travelling-sun no-place-to-land wrong-suitcase table-for-three last-train-scene verb-ser verb-estar verb-querer nearby-bangkok nearby-pattaya nearby-thailand'.split(),
    'airplane key tram.fill sailboat lightbulb bell book.closed map signpost.right.and.left envelope cloud.rain eye scissors door.left.hand.open book person.2 dollarsign.circle fork.knife film leaf lightbulb theatermasks backpack books.vertical leaf clock paintpalette basket leaf figure.run lightbulb questionmark.circle book.closed bell backpack tshirt house calendar bell shippingbox moon.stars sun.max sailboat suitcase moon theatermasks person.crop.rectangle key signpost.right.and.left fork.knife lightbulb tram.fill'.split()))


def words(text):
    return re.findall(r"[^\W_]+(?:'[^\W_]+)*", unicodedata.normalize('NFC', text.lower()))


def manuscripts():
    books = []
    for line_number, line in enumerate((SOURCE / 'stories.txt').read_text().splitlines(), 1):
        if not line.strip():
            continue
        if line.startswith('@'):
            fields = line[1:].split('|')
            if len(fields) != 5 or not all(fields):
                raise ValueError(f'Invalid book header at line {line_number}')
            book_id, author, title, english, summary = fields
            books.append(dict(id=book_id, author=author, title=title, englishTitle=english,
                              summary=summary, chapters=[[]]))
        elif line == '---':
            books[-1]['chapters'].append([])
        else:
            pair = line.split(' | ')
            if len(pair) != 2 or not all(pair):
                raise ValueError(f'Missing bilingual text at line {line_number}')
            spanish, english = pair
            speaker = re.match(r'^\[([^]]+)\] ', spanish)
            sentence = {'spanish': spanish[speaker.end():] if speaker else spanish, 'english': english}
            if speaker:
                sentence['speaker'] = speaker[1]
            books[-1]['chapters'][-1].append(sentence)
    if len({b['id'] for b in books}) != len(books):
        raise ValueError('Duplicate manuscript IDs')
    return books


def build():
    metadata = json.loads((SOURCE / 'metadata.json').read_text())
    lemmas = json.loads((SOURCE / 'lemmas.json').read_text())
    glossaries = json.loads((SOURCE / 'glossaries.json').read_text())
    meanings = json.loads((SOURCE / 'word-meanings.json').read_text())
    if set(glossaries) - set(metadata):
        raise ValueError('Glossary overrides reference unknown books')
    drafts = manuscripts()
    if {b['id'] for b in drafts} != set(metadata):
        raise ValueError('Manuscripts must cover every existing book exactly once')
    result = []
    for draft in drafts:
        chapters = draft.pop('chapters')
        if len(chapters) != 3 or any(len(c) < 4 for c in chapters):
            raise ValueError(f"{draft['id']} must have three substantial chapters")
        book = {**draft, **metadata[draft['id']], 'authorID': AUTHORS[draft['author']],
                'symbol': SYMBOLS[draft['id']], 'editorialRevision': 4,
                'license': 'Original fictional Cuentiva editorial edition. Native-speaker editorial review pending.'}
        # Three-chapter revision 4 leaves revision-2 passage IDs intact for saved reading progress.
        for chapter_number, (key, chapter) in enumerate(zip(('sentences', 'continuation', 'ending'), chapters), 1):
            book[key] = [dict(id=f"{book['id']}-r2-c{chapter_number}-{i}", **sentence)
                         for i, sentence in enumerate(chapter, 1)]
        visible = book['sentences'] + book['continuation'] + book['ending']
        counts = Counter(word for sentence in visible for word in words(sentence['spanish']))
        book['vocabulary'] = [dict(word=w, lemma=lemmas.get(w, w), occurrences=n) for w, n in sorted(counts.items())]
        contextual = {**meanings, **glossaries.get(book['id'], {})}
        missing = [w for w in counts if not isinstance(contextual.get(w), str)
                   or not contextual[w].strip()]
        if missing:
            raise ValueError(f"Missing {book['id']} glossary entries: {sorted(missing)}")
        book['matchGlossary'] = {w: contextual[w].strip() for w in sorted(counts)}
        if book.get('format') == 'movieScript':
            if not all(s.get('speaker') for c in chapters for s in c):
                raise ValueError('Every script line needs a speaker or narrator')
            book['scene'] = book['sentences'][0]['english']
        if book.get('verbFocus') and not set(book['verbFocus']['forms']) <= counts.keys():
            raise ValueError(f"Missing visible verb forms in {book['id']}")
        result.append(book)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    books = build()
    data = json.dumps(books, ensure_ascii=False, indent=2) + '\n'
    if args.check:
        if OUTPUT.read_text() != data:
            raise SystemExit('Books.json is stale; run scripts/rebuild_editorial_library.py')
    else:
        OUTPUT.write_text(data)
    print(f'{len(books)} books; {len(books) * 3} chapters; '
          f'{sum(len(b[k]) for b in books for k in ("sentences", "continuation", "ending"))} bilingual passages')


if __name__ == '__main__':
    main()
