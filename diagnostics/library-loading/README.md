# Indexed binary library experiment

The actual 52-book source is compiled to `Library.dat` (298,501 bytes) and the
single `cafe` book to `Introduction.dat` (5,127 bytes). Every Book property is
preserved, including continuation sentences, vocabulary, optional speakers,
verb forms, glossary entries and location metadata. Bundled editorial author
profiles still come from `Author.demoProfiles`; optional per-book personal
profiles are supported by the format.

## Results — 19 September 2026

Optimized Swift (`swiftc -O`), Apple Silicon Mac, macOS 26.0.1 / Swift 6.2.3.
Medians of 100 repeated operations; files can be in the OS cache. These are not
cold physical-device launch measurements or guarantees. No memory mapping was
requested: each operation reads through `Data(contentsOf:)`. Exact equality with
JSON-decoded Book values is checked before timing.

| Operation | Actual 52 books | Synthetic 500 books |
| --- | ---: | ---: |
| JSON read + all Book values | 7.107 ms | 68.481 ms |
| DAT read + header only | 0.019 ms | 0.042 ms |
| DAT read + first complete Book | 0.069 ms | 0.093 ms |
| DAT read + all Book values | 2.335 ms | 22.811 ms |
| Separate introduction file + complete Book | 0.061 ms | 0.063 ms |

Only the two **all Book values** rows are equivalent full-materialization work.
Header-only opening postpones construction. The 500-book fixture repeats the
real stories with different IDs; shared text is deduplicated, so this is not a
size prediction for 500 unique stories. Raw first-sample, median and p95 outputs
are in `results-52.txt` and `results-500.txt`.

A separate optimized real-repository test measured approximately 9 ms for a new
database open plus DAT loading, 38 ms for the catalogue import and 17 ms for
reading the stored catalogue. This is one isolated process/sample; see
`results-storage.txt`. It demonstrates work removed from first display, not the
cause of the historic multi-second launch delay. StoreKit, progress loading,
UI rendering and the real device still need end-to-end timing.

## Repeat

From the repository root:

```sh
python3 scripts/build_library_dat.py --check
bash diagnostics/library-loading/benchmark.sh

# An isolated synthetic scaling experiment; does not change shipped books.
python3 diagnostics/library-loading/make_scaling_fixture.py /tmp/cuentiva-scaling
bash diagnostics/library-loading/benchmark.sh \
  /tmp/cuentiva-scaling/Books.json /tmp/cuentiva-scaling/Library.dat

swift test -c release --filter BinaryLibraryTests/realLibraryPersistsAndReloadsWithSeparatePhaseTimings
```

## Shipping flow

- Edit the reviewed `Books.json` source. Xcode's **Compile bundled library** phase
  regenerates binary files in DerivedSources when the source or compiler script
  changes. Only the binary files are copied into the app. JSON is copied into
  the test bundle for equality checks, not into the installed app.
- Run `python3 scripts/build_library_dat.py` to refresh the committed binary
  fixtures used by package tests/benchmarks. `scripts/verify.sh` checks freshness.
- Launch reads the separate introduction and learner progress while StoreKit
  refreshes. Once purchase state is known, onboarding can appear without waiting
  for the full catalogue. Member screens still require their catalogue.
- An existing SwiftData catalogue remains authoritative. With no catalogue, the
  repository returns validated bundled binary books without importing/rereading
  them. The later sync first persists the bundle, then attempts network updates;
  an offline device still receives the local import. Failed import is retryable.
- The import commits only if the catalogue is absent. A late import cannot
  replace a newer downloaded catalogue. Ordinary database access stays on the
  shared store's worker actor. No second production container is introduced.
- The current Discover API still materializes all books into `[Book]`. This
  change does not claim a fully lazy reader or zero-allocation SwiftUI text.

## File format v1

The file is **not a dump of Swift object memory**. It has a defined little-endian
layout, offsets instead of pointers, and UTF-8 text. No JSON, XML, property-list
or Codable parser runs when opening or reading it. Selected text becomes Swift
Strings when a Book is requested. All byte accesses are bounds checked; numeric
loads are unaligned-safe. Unsupported versions and malformed text throw errors.

Header: 8 bytes `CUENLIB\0`, UInt32 version, UInt32 book count. Book records start
at byte 16, with a 140-byte stride. Offset/length pairs reference UTF-8 text;
offset/count pairs reference tables. Offsets are absolute file positions. An
optional value uses `0xffffffff` and a zero length/count to distinguish absent
from empty.

| Book byte offset | Contents |
| --- | --- |
| 0–87 | Eleven string descriptors: id, title, English title, author, level, symbol, summary, license, authorID, format, scene |
| 88 | UInt32 palette |
| 92 | UInt32 demo-location flag (0=false, 1=true, 2=absent) |
| 96, 104, 112, 120 | Sentence, vocabulary, continuation and glossary table descriptors |
| 128, 132, 136 | Optional verb-focus, location and personal-author record offsets |

Sentence stride is 32 bytes (four string descriptors); vocabulary stride is 20
(two strings plus UInt32 occurrences); glossary stride is 16 (key and value).
Verb focus is three strings plus a string-descriptor table. Location is four
little-endian doubles (latitude, longitude, accuracy, Date reference seconds)
plus a place-name string. Personal author is five strings. The generator
rejects unrecognised fields rather than silently dropping source information.

Changing the layout requires a version change, matching builder/reader updates,
and round-trip tests. Persisted SwiftData schema and downloaded JSON pack format
are unchanged.
