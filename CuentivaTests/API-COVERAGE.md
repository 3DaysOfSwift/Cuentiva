# API and test coverage audit

Latest immutable-core review: 126 model tests pass, including shared progress-load cancellation/failure/retry. Coverage includes purchase-gated content loading, access loss during loading, database-free core reads, first-progress-save rollback/retry, exact binary round trips, old-catalogue migration, failed snapshot writes and update activation on next launch. Updated RootViewModel tests are iOS-only and await runtime validation. The percentages below are historical measurements.

Measured 19 September 2026 after reorganising the tests. This is a snapshot, not a completeness certificate.

Subsequent investigation isolated the recurring crash to concurrent SwiftData container creation and tested a shared opening actor in a temporary project copy. See the [reproducer and findings](../diagnostics/swiftdata-store-opening/README.md). The opening safeguard is now applied: 114 model tests passed in 11 full parallel runs, including three new store-opening regressions. The coverage percentages below remain the original serial-run audit.

## Validation scope

- **111 model tests in 32 suites passed with `--no-parallel --enable-code-coverage`.** This serial run supplies the figures below.
- A parallel run terminated with signal 11 (`EXC_BAD_ACCESS`). The failing stack includes Core Data's `_generateTriggerSQL` during persistent-store creation. The earlier intermittent failure has recurred; this historical failure was subsequently isolated and mitigated as described above. Passing serially alone did not establish a fix.
- iOS AppModel/view-model/integration tests are separate from those 111 tests. Their sources are type-checked; runtime results and measured coverage await Command-U on a working simulator. CoreSimulator was unavailable to the agent in this environment.
- SwiftPM excludes `AppModel.swift`, SwiftUI/view models and Apple-specific audio, location and AI generators. Their coverage is **unmeasured**, not zero and not implicitly covered by model tests.
- Percentages below are executable **line coverage for each entire manager source file**, including helpers. They are not percentages of API scenarios, assertions or all possible input combinations. LLVM did not supply branch coverage here.

## AppModel API

`AppModel` is the composition root. Its instance API exposes `library`, `progress`, `purchases`, `learning`, `contributions`, `languageTerms`, `practice`, `nearby`, `chat`, `fantasy` and the `makeAudio` factory. It also has its injectable initializer and production `live()` / `shared` construction.

`AppModelTests/AppModelTests.swift` now checks that injected feature identities are preserved, that the audio factory is used, and that learning, practice and chat share the same completion/access state. It uses no live StoreKit, AI or production persistence. **This new test is not yet runtime-verified.**

`live()` and `shared` are intentionally not invoked by unit tests: doing so would open production storage and start real adapters. Their wiring still requires app launch and device/simulator integration validation. A giant test calling every feature through `shared` would hide failures and introduce shared state rather than provide complete coverage.

## Feature manager coverage

“Executed” below means the coverage report recorded at least one execution of the named manager method. It does **not** mean every branch was asserted. The operations listed are the app-facing feature contracts; additional manager conveniences are noted separately.

| Manager | Executable line coverage | Main test location |
| --- | ---: | --- |
| `ChatManager` | 108/109 (99.1%) | `FeatureTests/Chat`; shared integration/concurrency suites as applicable |
| `ContributionManager` | 54/60 (90.0%) | `FeatureTests/Contribution`; shared integration/concurrency suites as applicable |
| `FantasyManager` | 122/126 (96.8%) | `FeatureTests/Fantasy`; shared integration/concurrency suites as applicable |
| `LanguageTermsManager` | 8/8 (100.0%) | `FeatureTests/LanguageTerms`; shared integration/concurrency suites as applicable |
| `LearningManager` | 29/30 (96.7%) | `FeatureTests/Learning`; shared integration/concurrency suites as applicable |
| `LibraryManager` | 283/304 (93.1%) | `FeatureTests/Library`; shared integration/concurrency suites as applicable |
| `PracticeManager` | 28/28 (100.0%) | `FeatureTests/Practice`; shared integration/concurrency suites as applicable |
| `ProgressManager` | 317/319 (99.4%) | `FeatureTests/Progress`; shared integration/concurrency suites as applicable |
| `PurchaseManager` | 82/235 (34.9%) | `FeatureTests/Purchases`; shared integration/concurrency suites as applicable |

### ChatManager

Executed contract members: `beginSession()`, `endSession()`, `prepare()`, `authorizeSession()`, `conversation()`, `send()`, `clear()`.

Cost confirmation is required before sending, does not itself debit a coin, is idempotent within a session, and resets for a new topic. Unsupported/unavailable chat and empty wallets cannot authorize a session.

State exposed by the contract: `hasAccess`, `coins`, `sessionPaid`, `preparing`, `unavailable`, `ready`, `busy`. Property reads are not assigned execution status here because Observation-generated accessors are not consistently reported by source coverage.

Session payment, repeated messages, limits, invalid replies, unavailable generation, cancellation and recovery are covered with fake generators. Live on-device AI is not covered.

### ContributionManager

Executed contract members: `load()`, `save()`, `remove()`.

Not recorded as executed in this package run: `coaching()`.

State exposed by the contract: `drafts`, `topics`, `eligible`, `publishedCount`. Property reads are not assigned execution status here because Observation-generated accessors are not consistently reported by source coverage.

Legacy local drafts and topic submissions are covered. `coaching` is not directly exercised by the package suite. Repository remove/load failures and overlapping edits need focused cases.

### FantasyManager

Executed contract members: `refreshAvailability()`, `finishIntroduction()`, `load()`, `drawCreature()`, `saveDetails()`, `createIdentity()`, `createStory()`, `publishedBook()`, `publish()`.

State exposed by the contract: `profile`, `introductionSeen`, `availabilityMessage`, `stories`, `nextPublicationDate`. Property reads are not assigned execution status here because Observation-generated accessors are not consistently reported by source coverage.

Creature persistence, identity validation, private publication, weekly limits and failed saves are covered. Expand concurrent identity/story generation and cancellation cases; live Apple generation is outside this suite.

### LanguageTermsManager

Executed contract members: `search()`, `term()`.

Search and term lookup are exercised. View-model tests now cover clearing searches and unknown detail IDs; they await iOS runtime validation.

### LearningManager

Executed contract members: `canRead()`, `position()`, `check()`, `move()`, `finish()`, `finishReading()`, `advance()`.

Access gates, invalid answers, moving, completion and failed saves are covered. Cross-feature integration cases additionally exercise free introduction and continuation rules.

### LibraryManager

Executed contract members: `matchingBooks()`, `presentation()`, `load()`, `sync()`, `prepareDailyReads()`, `loadMoreDailyReads()`.

State exposed by the contract: `books`, `introduction`, `revision`, `syncing`, `syncMessage`. Property reads are not assigned execution status here because Observation-generated accessors are not consistently reported by source coverage.

Filtering, daily rotation, personal content, stable authors and worker reuse are covered. Expand sync-failure status and overlapping sync/preparation tests. Manager conveniences (`search`, `discover`, `books(by:)`, daily reads/authors) are also used by existing tests.

Nearby and its obsolete location tests were removed on 19 September 2026. Library tests now cover ordinary access to stories containing legacy location metadata.

### PracticeManager

Executed contract members: `allowed()`, `stats()`, `glossary()`, `recordScore()`, `best()`.

State exposed by the contract: `coins`, `week`. Property reads are not assigned execution status here because Observation-generated accessors are not consistently reported by source coverage.

Direct manager tests now cover access/completion gates, glossary validation, saved word baselines, best scores, coin preservation and failed persistence. Timer/input coordination remains in iOS view-model tests.

### ProgressManager

Executed contract members: `load()`, `registerLibrary()`, `saveDailyReading()`, `recordEncounter()`, `advanceReading()`, `savePosition()`, `complete()`, `completeReading()`, `setVocabulary()`, `setLearningLevel()`, `recordPractice()`, `installThemePack()`, `payForChat()`, `reset()`.

State exposed by the contract: `snapshot`, `revision`, `loaded`, `streak`, `week`. Property reads are not assigned execution status here because Observation-generated accessors are not consistently reported by source coverage.

Completion, rewards, vocabulary, levels, daily selections, resets, patches, queued saves and payment recovery are covered. More calendar/timezone boundaries and additional queued cancellation schedules would improve confidence.

### PurchaseManager

Executed contract members: `refresh()`.

Not recorded as executed in this package run: `purchase()`, `restore()`.

State exposed by the contract: `hasAccess`, `checking`, `offers`, `message`. Property reads are not assigned execution status here because Observation-generated accessors are not consistently reported by source coverage.

The package exercises coalesced refreshes and product-lookup failure/retry using injected clients. `purchase` and `restore` are not executed by the Mac package. The existing StoreKit integration test covers both plans, restoration, refund and missing-entitlement fallback, but awaits a simulator run. Pending/cancelled purchases, renewal, expiry and unverified transaction paths need more sandbox cases.

Fantasy also implements `PersonalLibraryFeature`: `libraryRevision`, raw `libraryContent`, `publishedBooks`, and `personalAuthor`. Revision/worker preparation and publication tests exercise this boundary. PurchaseFeature's offer/savings conveniences still need StoreKit-product-backed validation.

## View-model coverage

There are **22 production view models and 22 matching test files** under `ViewModelTests`. No empty placeholder suites were added. Existing tests have been preserved, including the combined Home/Completed workflow now under `IntegrationTests/LibraryPresentationTests.swift`.

New suites cover Author cancellation, Completed stale-response suppression, Chat sending/errors/session cancellation, theme installation failure/retry, paced writing unlock, language search and term details. One file per view model is an organisational rule, not an assertion of exhaustive coverage. Several older suites still cover only their main success path.

Priority follow-ups:

1. Run all iOS suites with Command-U and inspect coverage; address actual failures before relying on them for release.
2. Investigate the recurring parallel SwiftData/Core Data test-process crash with a smaller reproducer. Do not silently mark it resolved because serial tests pass.
3. Expand Chat prepare/clear/translation and late-error cases, duplicate theme-install taps, and Root initial-load failure/retry.
4. Add more Paywall pending/cancellation/error, Fantasy busy/cancellation and Settings failure-path tests.
5. Validate live StoreKit, speech, location and Apple Intelligence on supported hardware or simulator where supported.

## What “all possibilities” should mean

For each exposed operation, list the meaningful contract: valid input, empty/invalid input, access restrictions, state boundaries, persistence failure and retry, repeated invocation, and cancellation/overlap where it suspends. For a read-only property, assert the meaningful state transitions that change it. Keep each test focused enough that its failure identifies a behaviour.

Neither one test per function nor 100% line coverage proves all possibilities. Coverage tells us what code ran; the scenario matrix tells us what promises were checked. This audit deliberately leaves unverified areas visible.

### Editorial edition 2 — 20 September 2026

BinaryLibraryTests and the shared content integration test execute checks for 52 complete three-chapter books, 792 bilingual passages, current-reader two-chapter boundaries, valid cast attribution, vocabulary counts, glossaries, and six verb forms per chapter. Binary tests cover version-one compatibility, version-two round trips, malformed ending descriptors and invalid revision integers. CatalogueSyncTests cover an older offline snapshot, a newer remote revision, remote-only books and a missing revised bundle book without launch-time writes. LearningManagerTests cover restarting old-edition attempts while retaining completion and doubloon history. Coverage percentages above predate these changes and were not remeasured.

## Matching coverage — editorial revision 3

All 52 bundled books now include exact vocabulary-to-English coverage (4,260 pairs across 1,651 distinct Spanish surface forms). `PracticeManagerTests.everyBundledBookSupportsMatchingAfterCompletion` exercises availability, glossary acceptance and score persistence for every real bundled book without minting coins; it also checks contextual meanings for envelope, fence and “I walk”. Binary round-trip tests require nonblank glossaries for every book. The editorial generator rejects missing, null and whitespace-only meanings. Revision-2 passage IDs remain unchanged to preserve reading attempts.


## Three-chapter reading and daily matching — 2026-09-20

- Editorial revision 4 exposes all three chapters and rebuilds vocabulary/glossaries across the entire book: 5,771 pairs, with at least 71 per book. Binary round trips require complete nonblank matching data for all 52 books.
- `LearningManagerTests.threeChaptersResumeAndCannotCompleteBeforeTheEnding` covers the Chapter 2 boundary, failed saves and retries, resuming Chapter 3, rejecting premature completion, preserving the free introduction through its ending and awarding its reading coin once.
- `PracticeManagerTests.dailyGamesRequireThirtyPairsAndAwardExactlyOnceWithRetryAndRelaunch` covers 30 distinct pairs, partial rejection, ordinary practice isolation, one coin per game with saved balance receipts, final-save rollback/retry, replay/relaunch protection, revoked access, midnight expiry and record round trips.
- `LessonViewModelTests`, `BookReaderViewModelTests` and `PracticeViewModelTests` cover chapter presentation/resume, unaided three-chapter text, Chapter 2 audio without Chapter 1, interruption, five-pair board ambiguity protection, all 90 matches, each saved reward receipt, failed-save retry and repeat presentation protection. `MatchRewardViewModelTests` covers the balance reveal. Legacy group-reward saves and concurrent replay requests are covered in `PracticeManagerTests`.
- Validation: 145 shared-model tests pass. An isolated temporary macOS harness also executes 12 presentation-model tests in four suites (including three book-format cases). The harness uses copies of the production view models with app-singleton defaults replaced by required injected dependencies and fake audio; it does not render SwiftUI. Full iOS application sources and tests type-check. No simulator/device UI, speech-engine or StoreKit runtime validation was performed.

## Concurrent storage preparation — 2026-09-20

- Root launch starts progress preparation alongside entitlement verification and introduction loading. `RootViewModelTests.storageStartsWhileEntitlementCheckIsStillPending` holds the entitlement lookup open and verifies progress is loaded without publishing the paid library. Unpaid launch also prepares storage.
- A fresh local progress read opens the shared SwiftData database without seeding empty records; the persistence test retains first-write failure/retry checks. Existing progress-load overlap tests cover shared work and retry.
- Production purchase preparation awaits the same progress feature. `LaunchAccessTests.purchaseWaitsForStorageAndFailureCanRetry` verifies that failed preparation stops purchase processing and can be retried, using injected dependencies without contacting the App Store.
- Validation: 146 shared-model tests and 18 presentation-model tests passed. The temporary macOS presentation harness uses copied production view models with injected dependencies and substitutes an unsupported-device result for Apple Intelligence detection. It does not render SwiftUI. Physical-device launch duration and real payment-sheet presentation remain unmeasured for this change.

## Saved theme at startup — 2026-09-20

- ThemeManager restores a known saved palette before progress finishes loading, then checks installed-theme availability once the archive is known. An unloaded archive no longer temporarily rejects a previously selected reward theme.
- Tests cover Lavender before/after installed-pack loading, unavailable-pack fallback after loading, base-theme relaunch and obsolete preferences. All 22 presentation-model tests pass in the temporary macOS harness. Device launch-screen rendering is not validated by these tests; the static iOS launch storyboard remains a fixed Midnight colour.

## Match Pairs elapsed time — 2026-09-20

- The monotonic clock starts when the countdown completes and stops on the final match. The game displays elapsed time and the book's fastest completed time; ready/results show the same record. Daily 30-pair and full-deck records are separate.
- Fastest times persist atomically alongside scores/daily rewards, use the minimum valid positive finite duration, and can improve on replays without awarding another coin. Partial full-deck rounds cannot submit a completion time. Older progress without time records remains valid.
- Tests cover countdown exclusion, elapsed display, final-time freezing during save retries, interruption, slower/faster replays, invalid durations, partial-deck rejection, record round trips and reload. All 147 shared-model tests and 23 presentation-model tests pass. The presentation harness uses injected dependencies and a controllable clock; device UI rendering remains unverified.

## Optional whole-book reading guide — 2026-09-20

- Full-book reading retains its cover, three chapters, tap-to-reveal English and end credits. Explicit Begin/Pause controls drive either slow spoken-word highlighting or a silent word guide at an adjustable 80–240 words per minute. Audio can be switched during playback; the current sentence restarts so words are not skipped. Scene exit stops the guide.
- Chapter 2's existing automatic slow audio is preserved. Chat message playback now requests slow speech.
- Added presentation tests cover silent highlighting through all chapters without translation/completion side effects, audio toggle/pause behavior and slow chat speech/access denial. All 32 presentation-model tests pass in the isolated macOS harness using fake audio and controlled word gates. Real speech timing, sound and device layout have not been exercised for this change.

## Chat layout and suggested translations — 2026-09-20

- Chat uses the recipient's name as its navigation title, removes repeated bubble names and the language-help block, highlights translation/listen controls with additional spacing, and separates the suggested reply from the last message.
- Generated suggestions now include their own English translation, carried through reply delivery, conversation messages and legacy exchange projections. Optional decoding preserves older conversations without invented translations. The suggestion's English reveal is independent from message translation and resets on a new topic.
- Validation: 148 shared-model tests and 33 presentation-model tests pass, covering translation delivery, persistence round trips, legacy decoding and reveal state. On-device model generation and device layout remain runtime-unverified.

## Learner message translations — 2026-09-20

- Tapping a learner's message toggles its English below the Spanish. On-device generation supplies that translation alongside the corresponding storyteller reply; pending/older untranslated messages show an explicit availability note instead of blank or invented English.
- English is associated with the outgoing message ID and retained through conversation encoding and exchange projections. Tests verify delivery, JSON round trips, projection and independent per-message toggles/reset.
- Quick-start choices now have the heading “Start a conversation.” Validation: 148 shared-model tests and 34 presentation-model tests pass; actual on-device generation and visual rendering remain unverified.
