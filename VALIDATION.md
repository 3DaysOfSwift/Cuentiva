## Decipher language terms — 17 September 2026

Added Settings → Language help → Decipher language terms, with 12 bilingual entries, plain-language explanations, highlighted English/Spanish examples and related-term navigation. Search supports either language and accent-insensitive matching. The Your turn word-family statistic links to the lemma explanation. No quiz or new learning rewards are introduced.

All 29 core tests passed, including bilingual search and validation that related links resolve. Xcode Simulator tests passed. On iPhone Air Simulator verified the Settings route, bilingual list and Adjective detail with formatted examples. Both views use the shared theme and scalable text; physical-device VoiceOver and maximum Dynamic Type remain manual checks.

## Library-shaped startup — 17 September 2026

Replaced the small title/spinner view with a noninteractive library skeleton containing the title, heading, placeholder controls and covers, and tab shell. Root background now fills the window and safe areas. Load errors show Retry over the shell; entitlement checks still gate content. Root load calls are serialized to avoid overlapping launch/foreground work.

Added a static LaunchScreen storyboard in App Resources and verified the built Info.plist points to it. Its cream/green library shell replaces the empty generated launch screen; static launch resources cannot read the user's saved custom theme, while the SwiftUI skeleton immediately uses that theme.

Xcode build/test suite passed. Installed and launched on iPhone Air Simulator; the library loaded with progress preserved. The fleeting pre-SwiftUI frames were not captured by the UI tool, and the physical-device black flash/cache behavior still needs checking with the updated build.

## Your turn and matching practice — 17 September 2026

- All 28 core tests and the Xcode Simulator test suite passed. Tests cover baseline capture, legacy-history honesty, daily completion celebration idempotence, persistent once-per-book doubloons, failed-save rollback, full glossary coverage, interrupted rounds, countdown timing, expired-input rejection and replay rewards.
- iPhone Air Simulator: opened the visible Completed activities menu, ran a 30-second café round, matched a pair, and observed timeout → result → +1 gold doubloon. Opened Your turn, verified Spanish-only content, tapped a sentence to reveal English, and reached the accurate legacy-data statistics screen (95 tokens, 62 forms, about 58 families).
- Supported matching content: full authored glossaries for café and garden. Other books remain available for unaided reading but explicitly defer Match Pairs until their glossaries exist. No runtime-generated translations or partial decks presented as complete.
- Physical-device Dynamic Type/VoiceOver, visual streak-entry timing and the full unaided pacing session still need hands-on validation. Existing installations without full historical word-form tracking show unavailable before-book stats rather than invented counts. Coins have no spending feature.

## Nearby layout correction — 17 September 2026

Moved the fixed-size decorative circle into an overlay so it cannot impose a minimum cover width. Nearby uses adaptive vertical cards with descriptions below the covers, replacing the cramped 120-point horizontal cover rows. Xcode build passed. On iPhone Air Simulator with a simulated Pattaya coordinate, permission and place-name lookup succeeded and all three example stories loaded. The visible first card stays inside the horizontal margins; Discover's existing two-column covers were also visually checked. Full lower-card scrolling and physical iPhone layout were not verified by automation.

## Thailand Nearby examples — 17 September 2026

Added three original A2 fictional travel stories at explicit example locations in Bangkok, Pattaya and Chiang Mai. Each has eight guided and eight continuation sentence pairs, with full vocabulary indexing. Nearby defaults to 1,000 miles (1,609.344 km), while smaller radii remain available. The reader's location still comes from the location provider; it is not hard-coded to Pattaya.

Xcode tests and all 25 core tests passed. Bundled-content checks verify 52 books, aligned text and vocabulary counts, three valid example geotags, and all three within 1,000 miles of Pattaya. Live GPS/location permission on the user's phone was not exercised in this content update.

## Nearby Stories — 17 September 2026

- Xcode Simulator tests passed; all 25 core tests passed. Final view-only changes built successfully afterward.
- New tests cover distance/radius filtering, stale browsing fixes, purchase gating, ordinary versus geographically restricted discovery, completed-book access after travel, immutable submission coordinates, stale submission rejection, and local deletion.
- iPhone Air Simulator: installed and opened Nearby Stories; verified the themed tab, distance control and contribution navigation with “Leave this story here” enabled. Existing progress and drafts remained available.
- Live device permission, GPS accuracy, MapKit locality lookup, denial/timeout and confirmation persistence still need on-device checks. No real location was obtained in the UI test. No fabricated community locations were attached to existing books.
- Server publishing, server-side geographic access enforcement, immutable server metadata and remote privacy withdrawal remain future integration work; local drafts do not appear as published nearby books.

## Reader audio-session warnings — 17 September 2026

- Removed manual playback category/activation and unconditional deactivation on every sentence. AVSpeechSynthesizer now manages its separate playback session (`usesApplicationAudioSession = false`), as documented in the installed Apple SDK.
- Microphone category/activation/deactivation are serialized on a dedicated queue, off MainActor. Generation checks prevent a stopped or superseded activation from starting recognition or publishing a stale error. Only requested microphone sessions are deactivated.
- Xcode iOS Simulator test suite passed. All 23 core tests passed. These tests do not validate physical-device audio routing or reproduce the supplied underflow log.
- Retest continuous story narration, speaker toggling, microphone switching, headphones and interruptions on the affected iPhone. System accessibility, buffer-underflow and unsafeForcedSync diagnostics are not claimed to be fixed without a device reproduction/call stack.

## Completion first-appearance timing — 17 September 2026

- Initialize the previous total before the completion view renders. Run entrance, a short settled pause, counter animation and confetti in one cancellable sequence.
- Xcode simulator test suite passed, including new first-receipt/repeated-preparation/new-receipt and reread counter checks.
- On iPhone Air Simulator, the first completion after launch visibly animated the number to 9. A subsequent completion animated 9 to 10; captured frames show the confetti beginning to enter from below the screen.
- Reduce Motion continues to display the final total immediately and suppress confetti. The affected physical iPhone's setting and behavior with this build remain unverified.

## Contribution topic requests — 17 September 2026

All 23 core tests and the Xcode simulator suite pass. Coverage includes legacy draft decoding, exact word/diacritic checks, incomplete topic submission rejection, persisted topic links and teaching notes, no publication/coverage increment after submission, and preserving work when changing writing paths. Visually verified Contribute → Topic requests → Haber selection on iPhone Air, including the missing-coverage card and linked draft with teaching fields, form counts, and self-review checklist. Latest build installed. Editorial priorities and coverage are seeded local data; shared assignments, real demand analytics, server moderation, and publishing are not connected.

## Verbs content type — 16 September 2026

Added Verbs to Discover/Completed type filtering and sorting, with three original 24-sentence books (12 guided plus 12 continuation). Tests validate all six target present-indicative forms in both halves and their verb lemma mappings. All 20 core tests and the Xcode simulator suite pass, including verb filtering, delayed completion, persistence, and playback. Visually verified Verbs selection, three matching books, and the tense-labelled Ser lesson with anchored Next on iPhone Air. Latest build installed. The initial scope is present indicative with vosotros, not every tense/mood or regional voseo. Native-speaker editorial review is pending.

## Anchored guided-lesson action — 16 September 2026

Moved the shared guided lesson’s Next / Read the full story / Read the full script action into a bottom safe-area inset. It stays outside the scrolling content, uses the current theme, and reserves content space. The second-stage reader’s Mark as read button remains inside its scroll content. Xcode simulator build passed; visually verified the anchored action in both Ana’s little café and The wrong suitcase on iPhone Air. Updated build installed. No progression logic changed.

## Extended story reader — 16 September 2026

All 19 core tests and the Xcode simulator suite pass. Both story and script formats exercise delayed completion, save rollback/retry, duplicate-safe totals, slow playback, audio stopping/restarting, and no completion when audio ends. A specific test confirms the free café introduction remains accessible through its continuation and locks only after Mark as read. Story reader-stage resumption is covered by view-model tests. All 46 books have a continuation exactly matching their guided sentence count, aligned translations, unique sentence IDs, and validated vocabulary counts. The 43 stories add 370 new pairs. Original guided text/IDs and existing lemma mappings were checked against the previous committed catalog and retained.

On iPhone Air, entered My father’s garden from its last guided sentence, observed the single-column bilingual reader, automatic playback and following through the new continuation, then used Mark as read. The celebration showed 16 sentences / 104 Spanish words and increased Books Learned from 4 to 5. Latest build installed. Physical-device listening, extreme Dynamic Type/VoiceOver checks, and native-speaker editorial review remain pending. Previously completed books retain their achievement when content expands.

## Full-script reader — 16 September 2026

All 18 core tests and the Xcode simulator suite pass. Added coverage for delayed script completion, persisted reader-stage resumption, atomic save failure/retry, duplicate-safe totals, slow sequential playback, speaker-change pauses, stopping/restarting audio, and no automatic completion at audio end. Content checks cover original and continuation vocabulary; each continuation has exactly as many turns as its guided script.

On iPhone Air, exercised all ten guided turns of The wrong suitcase, entered the full reader, observed automatic highlighting and scrolling through the continuation, toggled audio off/on, and used Mark as read. The celebration displayed 20 lines and Books Learned increased from 2 to 3 only after that action. Updated build installed. Physical-device audio quality and timing still need listening review; automated playback tests use a replaceable audio adapter.

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

## Purchase recovery — 17 September 2026

Verified lifetime purchase results now grant access before finishing the transaction;
revision checks prevent older in-flight entitlement scans overwriting newer results.
Unlock first checks existing ownership, purchase errors recheck entitlements, and
restore clears stale errors. Purchase/restore operations reject overlapping starts.
Only verified matching non-consumable transactions grant access; refunds remove it.

29 core tests and all 55 Xcode simulator tests passed. Added a real StoreKitTest
session exercising purchase → root access, a fresh PurchaseManager with existing
ownership, restore, duplicate Unlock (one transaction only), and asynchronous refund
revocation followed by refresh. This simulates loss of app-local purchase state;
it does not constitute deleting/reinstalling on the user's physical phone.
The specific device-side StoreKit error has not been reproduced or diagnosed from
its generic screenshot. Rebuild on the phone and use Restore purchases in the same
StoreKit test environment; purchase errors now include recovery guidance and logs.

## Physical-device lifetime recovery — 17 September 2026

Confirmed in Xcode's transaction manager that J.A.R.V.I.S had a Purchased lifetime
transaction (12:07:50) while the app's current-entitlements query returned no matching
purchase and no verification failure. Recovery now also checks Transaction.latest
for the lifetime product and accepts only verified, matching, non-consumable,
non-revoked, non-upgraded transactions. Unverified purchases remain locked and
produce a verification-specific error rather than being described as missing.
Deployed via Xcode to the connected phone: logs confirmed latest transaction active
and access true. No transactions were deleted, refunded, or created on that phone.
The cause of StoreKit's empty index is not established; the recovery path is confirmed.

Regression coverage injects an empty current-entitlement result while using a real
StoreKitTest lifetime transaction, then verifies recovery and refusal after refund.
Final verification: all 55 Xcode simulator tests and 29 core tests passed, including
the empty-index recovery and revoked-latest-transaction regression assertions.

## Settings selection tint — 17 September 2026

Settings applies the active accent explicitly to its selection controls and list.
Theme-dependent identities rebuild individual native pickers after a palette change,
without rebuilding the entire Settings screen or discarding its ViewModel.
Simulator build passed. Switched Library → Midnight on iPhone Air and visually
confirmed the theme selection and visible vocabulary values use the light green
accent together. Physical-device scrolling/reuse remains a follow-up check.

## Settings restore feedback — 17 September 2026

Purchase section shows verified lifetime access status. Restore disables repeat taps,
shows Checking purchases while active, and displays success or failure beside the
action. Existing ownership reports full access already active; new recovery reports
restored access. Failed/no-access results never show success and stale feedback clears
on retry. All 57 Xcode tests and 29 core tests passed. Simulator tap confirmed the
existing-owner success message appears inside the Purchase section.

## Vocabulary screen and self-selected level — 17 September 2026

Settings now links to a dedicated Your vocabulary screen with an always-visible
search field, editable word states and six A1–C2 choices. The optional self-selected
level persists through ProgressManager's atomic save, is backward-compatible with
older JSON, can be cleared and is removed by Reset learning progress. It is not an
assessed CEFR level and does not auto-promote, rewrite vocabulary or gate books.
Tests cover search, editing, persisted level, failed-save rollback, reset and older
JSON. All 59 Xcode tests and 31 core tests passed. Simulator navigation verified the
short Settings entry, visible search, level choices and word controls. Level choices
were subsequently arranged into two rows of three; final build passed.

## Hide completed books — 17 September 2026

Discover now offers a themed Hide completed books switch below the existing
filters. LibraryManager combines this with search, difficulty, type and sorting.
Completion updates remove the book from filtered results immediately; Completed
remains available for rereading. Empty results offer Show completed books.
The existing Home/Completed regression now covers filtering before and after a
committed completion and combining difficulty/search/type/sort. Xcode simulator
tests and all 31 core tests passed. No physical-device visual check this change.

## Discover next read — 17 September 2026

Completed books are hidden by default. Discover opens with Your next read, a
cover, English title, difficulty, length, summary and Read this book / Continue
reading action. LibraryManager chooses an unfinished accessible book first,
then an unread book at the self-selected level, then library order. Suggestions
exclude completed books and respect location/access rules; an exhausted library
has an explicit message. Browsing controls and the collection remain available.
All Xcode simulator tests and 32 core tests passed. Regression covers default
hiding, gated suggestions, unfinished priority, unavailable-level fallback and
completion exhaustion. Simulator screenshot verified the header and Continue
reading button fit on the initial iPhone Air screen. No physical-device check.

## Community authors — 17 September 2026

Discover's community heading now introduces Ana, Luis and Marta through generated
illustrated portraits and links to dedicated profiles. Profiles include a short
introduction, Behind the story note, accessible books and a contribution link.
All profiles/notes are explicitly fictional demo content, not verified memoirs.
Book.authorID is optional for backwards compatibility; three bundled books link
to stable profile IDs. LibraryManager enforces access and location visibility
when listing author books, and keeps completed books available for rereading.
No live publication/moderation service or automated approval is represented.

All 33 core tests and Xcode simulator tests passed. Initial Xcode test launch
failed with Simulator Busy/preflight; a retry passed. Tests cover stable author
mapping, access gating, legacy decoding and rereading. Simulator confirmed the
three author links, opened Ana's profile and rendered its portrait, introduction,
note and completed book correctly. No physical-device check this turn.
