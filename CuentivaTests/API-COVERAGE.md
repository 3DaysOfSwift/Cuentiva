# API and test coverage audit

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
| `NearbyManager` | 22/25 (88.0%) | `FeatureTests/Nearby`; shared integration/concurrency suites as applicable |
| `PracticeManager` | 28/28 (100.0%) | `FeatureTests/Practice`; shared integration/concurrency suites as applicable |
| `ProgressManager` | 317/319 (99.4%) | `FeatureTests/Progress`; shared integration/concurrency suites as applicable |
| `PurchaseManager` | 82/235 (34.9%) | `FeatureTests/Purchases`; shared integration/concurrency suites as applicable |

### ChatManager

Executed contract members: `beginSession()`, `endSession()`, `prepare()`, `conversation()`, `send()`, `clear()`.

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

### NearbyManager

Executed contract members: `stories()`.

Access, radius and location filtering are covered. Request cancellation has separate concurrency tests; real CoreLocation permission and geocoding still require device/simulator validation.

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
