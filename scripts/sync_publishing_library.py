#!/usr/bin/env python3
"""Export the app's books and actual Swift storyteller profiles to the publisher."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

APP = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--publisher', type=Path, default=APP.parent / 'GlobalEnglish-SpanishLearningBooksCollection')
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix='cuentiva-authors-') as directory:
    work = Path(directory)
    source = work / 'Export.swift'
    source.write_text('''import Foundation
@main struct Export {
    static func main() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        FileHandle.standardOutput.write(try encoder.encode(Author.demoProfiles))
    }
}
''')
    subprocess.run(['xcrun', 'swiftc', '-module-cache-path', str(work / 'cache'),
                    str(APP / 'Cuentiva/2 - AppModel/Features/Library/Author.swift'),
                    str(source), '-o', str(work / 'export')], check=True)
    authors = subprocess.check_output([str(work / 'export')]) + b'\n'
books = (APP / 'Cuentiva/3 - App Resources/Books.json').read_bytes()
for name, data in [('books.json', books), ('authors.json', authors)]:
    destination = args.publisher / 'content' / name
    if args.check:
        if json.loads(destination.read_bytes()) != json.loads(data):
            raise SystemExit(f'Out of sync: {destination}')
    else:
        destination.write_bytes(data)
print(f'{"Verified" if args.check else "Exported"} {len(json.loads(books))} books and {len(json.loads(authors))} storytellers.')
