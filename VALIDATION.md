## Movie Scripts and library controls — 16 September 2026

Added three original scripts (46 books total), optional format/scene/speaker metadata, role selection, and shared type filtering and sorting for Discover and Completed. Existing JSON decodes as Stories. All 17 core tests and the Xcode simulator test suite pass, including combined access/filter/completion checks and role-selection/manual-completion behavior. Verified Movie Scripts filtering, title sorting, and role selection visually on iPhone Air. Installed the updated build there. Dialogue uses the existing single Spanish voice with manual playback.

# Validation — 16 September 2026

## Gravity, the Sun, and gas giants

Added three science stories with fictional characters and 30 bilingual sentence
pairs. All 43 books pass decoding and vocabulary-index checks; all 16 core tests
and the iOS Simulator suite pass. The catalog has 8 A1, 18 A2, and 17 B1 books.
NASA references and scientific qualifications are in SPACE-STORIES.md.
Native-speaker review remains pending.

## Work, travel, and imagined futures

Added six original bilingual books (62 sentence pairs), bringing the catalog to
40: 8 A1, 17 A2, 15 B1. All 16 core tests and the iOS Simulator suite pass,
including vocabulary occurrence checks for all 40 books. Existing IDs are unchanged.
The cattle story distinguishes common and scientific names; the AI future is
explicit fantasy. Text and sources are in WORLD-STORIES.md. Native-speaker review
remains pending.

## Second journal-derived collection

Added 14 original fictional microbooks with 112 bilingual sentence pairs.
All 34 books decode and pass the per-word occurrence/index checks; all 16 core
tests and the iOS Simulator suite pass. Library distribution is 8 A1, 14 A2,
12 B1. Existing IDs and progress are preserved. Installed on iPhone Air Simulator.
Health/science assertions and literary scope are documented in JOURNAL-CONTENT-NOTES.md;
full bilingual text is in JOURNAL-STORIES.md. Native-speaker review remains pending.

## Expanded life-skills library

Added 15 original fictional microbooks: 122 bilingual sentence pairs and 1,034
Spanish word occurrences. The library now has 20 books (5 A1, 8 A2, 7 B1).
All 16 core tests and the iOS Simulator suite pass. The bundled-content test
checks every vocabulary occurrence count, unique surface entries, alignment,
and nonempty lemmas. Existing book IDs and the introductory gate are retained.
Installed on iPhone Air Simulator. Native-speaker editorial review remains
pending; sources and vocabulary limitations are recorded in CONTENT-NOTES.md.

## Confetti appearance correction

Replaced the embedded UIKit appearance observer with an explicit SwiftUI entrance
animation and its completion callback. This handles completion being inserted into
an already-presented lesson. Confetti starts after the 0.4-second entrance finishes,
respects Reduce Motion, and clears on dismissal. The iOS Simulator suite passes.
Installed the updated build on iPhone Air, reread the already-completed café book,
and visually confirmed confetti over its completion screen; the total stayed at 2.
This supersedes the earlier unverified UIKit observer implementation below.

## One-time purchase

Configured a $4.99 non-consumable lifetime product and removed trial eligibility,
subscription management, recurring price copy, and expiry polling. Restore and
verified entitlement/revocation handling remain. All 16 core tests and the iOS
Simulator test suite pass. Gate coverage verifies that completed onboarding cannot
be reread before purchase and can be reread after unlock. Actual StoreKit purchase,
restore, and refund dialogs still require manual verification with the new product.
App Store Connect has not been configured by this change.

## Completion confetti

Added a finite 3.2-second Canvas burst from the screen's bottom corners. A UIKit
viewDidAppear observer starts it after presentation, replacing the previous guessed
450ms delay. The overlay ignores touches and accessibility, honors Reduce Motion,
and cancels its lifetime task when the completion view leaves. Particle colors use
the active theme. All 16 core tests and the iOS Simulator test suite pass.
The Simulator test launch initially failed because the device was shut down;
booting it and rerunning succeeded. Visual timing and particle appearance
still require hands-on confirmation on the completion screen.

## Slow playback, redaction, and demo icon

The iOS Simulator build/test run passed, and all 16 core tests passed. Slow speech
now uses rate 0.20 (previously 0.35); normal remains 0.47. Write uses native
placeholder redaction with the Spanish sentence layout and an accessibility label
that does not expose the answer. Speak, hint, and checked feedback still reveal it.
The new forest/cream community-book icon is included in the app asset catalog as
an opaque 1024px image, configured for both app build configurations.
Perceived speech speed and VoiceOver/redaction presentation still need hands-on
verification; automated tests do not assess those experiences.

## Reading-first refinement

The Simulator test suite passed after removing compulsory sentence checks.
Regression coverage now includes completing a book purely by advancing, saved
reading position, streak/vocabulary updates from reading, duplicate-safe rereading,
atomic failure behavior, and retaining writing across tabs and sentence navigation.
Check my words uses explicit white text on a dark theme-defined background in
both palettes. The Skip control and forced revisit flow are removed.

## Speech callback correction

A subsequent Simulator test run passed after correcting the audio callback boundaries.
The recognition-result handler is explicitly Sendable/nonisolated, extracts value data,
and publishes on MainActor. The audio tap is constructed in a nonisolated factory and
skips empty buffers without moving PCM buffers across a Task boundary. Speech permission
completion is explicitly Sendable. Two regression tests invoke the result handler and
audio tap from detached tasks; the result test asserts main-actor publication.

This addresses a callback-isolation defect consistent with the reported dispatch queue
assertion. The screenshot did not show the full call stack, so the exact reported crash
has not been conclusively matched. Live microphone and voice-asset behavior still need
retesting on the affected simulator/device. Simulator voice metadata warnings were not
claimed to be repaired by this app change.

## Latest verification — theme update

A direct standalone Xcode invocation successfully built and executed **25 tests in six suites** on the iPhone 17 / iOS 26.2 Simulator. This includes all eight screen-model tests, the fifteen core tests, and two new tests for theme persistence and obsolete-selection fallback. No compiler sandbox workaround was needed for this invocation.

Library and Midnight are selectable in Settings. Fixed white input surfaces and the app-wide forced light appearance were replaced with the selected palette. ThemeManager is now in its own file; one app-owned instance is shared through the SwiftUI environment. The privacy manifest declares the app-preferences use of UserDefaults.

The earlier Simulator limitation below is historical: shell output redirection reproduced the connection failure, while the otherwise equivalent direct tool invocation succeeded. Visual inspection of every screen in both themes and the physical-device speech checks remain pending.

## Initial verification

- Xcode 26.2, Swift 6 strict-concurrency compilation: **passed**.
- Generic arm64 iOS Simulator `build-for-testing`: **passed**, including the app and iOS test bundle.
- macOS core test execution: **15 tests passed** in four suites.
- Core coverage includes edit-distance alignment, accent and ñ handling, duplicate completion, partial lessons, subscription gating, streak day boundaries, vocabulary evidence, collection filtering, local review states, bundled content indexing, atomic disk round trips, and corrupt-file error handling.
- Eight screen-model tests are included and compiled in the iOS test target. They were not executed here.
- Five bundled books validate as aligned bilingual sentence records with indexed vocabulary counts.

## Environment limits

Simulator services were inaccessible in this Codex session. Additional Simulator/cache filesystem permissions were requested but not granted. Consequently, the app has not been launched or visually inspected in Simulator, and the iOS tests, local StoreKit purchase dialogs, and microphone path have not been runtime-tested here.

For compiler verification in this nested sandbox, the invocation used the Swift compiler's `-disable-sandbox` helper flag; the enclosing workspace sandbox remained in force. That environment-only flag is not saved in the Xcode project. Build/cache files are outside the deliverable repository.

## Hands-on verification in Xcode

1. Run the Cuentiva scheme with its StoreKit file selected. Complete onboarding with writing, then confirm the celebration and paywall appear.
2. Decline the offer; confirm no library, completed shelf, or contribution access. Restore remains available.
3. Make the local one-time purchase. Confirm all 20 books appear and the introduction already has its completion tick.
4. Search and filter A1/A2/B1. Complete another book; verify one new counter increment and its appearance in Completed.
5. Relaunch during a lesson; verify saved position and attempts. Repeat a completed book; verify no duplicate counter increment.
6. Use Xcode's StoreKit transaction manager to refund/revoke the purchase. Confirm the feature gate returns and preserves progress. Restore a non-revoked purchase; confirm the shelf returns. Verify there is no renewal or trial offer.
7. On a supported physical iPhone, check Spanish synthesis, slow playback, highlighting, speech recognition, permission denial, interruptions, screen changes, and app backgrounding. Ensure Write works when recognition is unavailable.
8. Check VoiceOver, large Dynamic Type, Reduce Motion, landscape, and iPad layout. Spanish text has a Spanish locale, but correct VoiceOver pronunciation needs device verification.
9. Save and reopen a contribution draft. Submit it locally; verify pending-review status and zero published contributions. Nothing should upload.

## Not production-ready

No production StoreKit product, hosted privacy policy, remote publishing API, real AI editor, native-speaker content review, or brand clearance is configured. The approved $4.99 one-time price is configured locally; App Store Connect configuration is pending. App icon and final branding are intentionally not finalized.
