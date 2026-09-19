# Prepared core library and local progress

## Launch

RootViewModel owns startup and presentation. Concurrent member-load callers share one pending task; progress loads are likewise coalesced by the Progress feature. Cancelling one caller does not cancel work another caller needs. The library feature enforces access,
so another screen or future target cannot bypass the purchase gate.

1. Read the separate `Introduction.dat` and saved progress concurrently with
   StoreKit verification. Never read the full core library while access is
   unconfirmed or denied. The free introduction remains available afterward.
2. Once StoreKit confirms access, read the installed `core-library.dat`, or the
   bundled `Library.dat` if no usable downloaded snapshot exists. This operation
   does not open SwiftData, import records, save files or contact GitHub.
3. Show the member library when both core content and progress are ready. Do not
   briefly show invented zero progress. First-time users have empty progress
   without creating a database; the first real save creates it atomically.
4. Prepare core updates after initial content is ready. A purchase or restore
   during onboarding starts the member load. Scene activation is coalesced with
   startup; returning from the background refreshes access.

Books, filtering and recommendation preparation run on repository/worker actors.
The current Discover API constructs all core books as Swift values. It is not a
fully lazy reader: indexed, per-level loading remains a possible measured
optimization, not an implemented claim. No separate curriculum files or add-on
pack system are introduced in this change.

## Core updates

GitHub publishes the core catalogue. JSON is a transport/source format, not a
runtime database. The repository downloads changed packs, checks size, checksum,
book IDs and author references, and caches verified payloads as files so an
interrupted download can resume.

A complete replacement is compiled off MainActor into one `.dat` snapshot with
book offset tables, UTF-8 text, storyteller profiles, manifest and arrival dates.
Small metadata uses a binary property list; book content does not. The snapshot
has a version and SHA-256 integrity checksum. The exact encoded content is read
back and compared before an atomic file replacement. Cancellation before that
replacement leaves the old snapshot intact.

The repository keeps the current session's catalogue in memory. A newly created
repository on the next process launch adopts the replacement. Stable book IDs
preserve progress. Personal publications remain independent and can appear in
the current session. Invalid downloaded snapshots are logged and fall back to
the bundled core; their files remain until a successful update repairs them.
This integrity check is not encryption or a substitute for StoreKit verification.

Automatic update checks are limited to once per hour within a session. Settings
can request a check. These are owned in-process async operations, not a promise
that iOS will continue downloading after suspending the app.

## Mutable state and compatibility

One shared SwiftData container stores progress, rewards, profiles, personal
stories and drafts. Its path and schema are unchanged. Contexts remain on model
actors; saves are explicit, progress mutations are FIFO, and failures roll back.
The first progress transaction writes the complete baseline and readiness marker;
later transactions update changed records only.

Existing catalogue records from the previous implementation are converted into
a core snapshot during background preparation, before the network check. After
the snapshot is verified, only obsolete catalogue/pack database collections and
old catalogue JSON files are removed. Progress is never removed. During that
one transition, the launch uses the bundled core and the migrated core becomes
available next launch. Failed migration retains its source for retry.

Old mutable JSON archives still migrate on first access where necessary to
preserve user data. That compatibility path can write; normal launch reads do
not. Corrupt mutable data reports an error instead of replacing it with defaults.

## Measuring

Use a fresh physical-device install and an existing installation, both inside
and outside the debugger. Record StoreKit, introduction, progress, database-open
and core-library phase logs separately. Readiness logs are not first-frame
measurements. Core `.dat` loading now has no database dependency; existing
progress can still require a database open, and StoreKit still gates paid access.
See `diagnostics/library-loading` for reproducible data-only benchmarks.
