## Architecture refinement — 19 September 2026

- View refresh identifiers now contain small revision tokens instead of complete catalogue/progress snapshots. Library worker inputs are private; personal publication sorting happens in the worker for these requests.
- Completed, author and search queries skip Discover preparation. Discover reuses daily recommendations, author selection and vocabulary coverage across filter changes until its inputs change.
- Progress persistence generates a patch of changed records. SwiftData fetches affected records by identity and commits the patch atomically, with rollback on failure; ordinary saves no longer fetch the entire record collection.
- Concurrent purchase refresh callers await the same feature-owned operation, including product loading. Cancelling one waiter does not cancel the shared refresh, and a failed lookup permits retry.
- Added five focused tests covering preparation reuse, revision changes, shared purchase refreshes, record deltas and transactional rollback/retry. All 106 core tests passed. App and all test sources passed Swift 6 iOS SDK type-checking; project/plist and whitespace checks passed.
- No test-process crash occurred in this pass; the earlier intermittent signal-11 failure remains unresolved. Xcode simulator testing was attempted but CoreSimulatorService was unavailable (destination lookup failed, exit 70). Simulator UI and live StoreKit behavior remain unverified by this pass.

## Concurrency fixes — 19 September 2026

- Progress mutations use a FIFO asynchronous gate, spanning repository I/O. Validation and rewards are calculated from the latest committed state after acquiring a turn. Failed saves leave the snapshot unchanged; cancelled queued operations do not write; later operations still run. Completion receipts are created inside the transaction, preventing duplicate rewards under overlap. Disk encoding and writes remain in the repository/storage actors.
- Chat payment persists a recoverable admission before synchronously checking the session and delivering the first reply. Dismissal/cancellation during payment keeps that credit usable, including after relaunch, without writing during launch. A failed final settlement intentionally retains credit even if the reply was delivered; recovery favours the learner rather than risking lost coins. SwiftData progress records include the optional admission marker.
- Location continuation ownership now has request tokens, cancellation cleanup and exactly-once completion. Apple adapters stop updates, cancel geocoding/timeouts and discard callbacks from older CLLocationManager instances. Nearby owns/cancels its task when leaving the screen or entering the background and suppresses stale results/errors.
- Discover filtering, ordering, daily recommendations, author selection and vocabulary coverage run on LibraryWorker. Home, Completed and author screens render prepared results; input changes restart their view tasks, with cancellation/input checks rejecting stale responses. Existing recommendation/recycling, personal-book, purchase-access and daily-selection tests exercise the asynchronous API.
- Added ten core concurrency tests (including two dismissal/cancellation variants) and two simulator view-model tests. The core suite passed all 101 tests. App and all test sources passed Swift 6 iOS SDK type-checking. Project/plist and whitespace checks passed. Forced-unwrap/forced-cast/forced-try audit found no code occurrences.
- No test-process crash occurred during this pass; the earlier intermittent signal-11 failure remains unresolved. Xcode simulator tests were attempted but CoreSimulatorService was unavailable and no destination matched. The two new view-model tests are type-checked, not runtime-verified. Real CoreLocation permission/geocoding lifecycle and simulator UI behavior still need device/simulator validation.

## Clarity cleanup — 19 September 2026

- Practice APIs now record scores and return no fabricated reward flag. Removed the unused `awarded` state and renamed the retry action to saving a score. Persistence assertions check saved best matches and unchanged coins. Corrected a view-model fixture that requested more matches than its book contained.
- Removed unused chat notice state left over from the purchase flow. Paywall async actions are expanded into readable steps. Product lookup and annual-plan savings live in the purchase model; the legacy lifetime identifier is explicitly named.
- Extracted transaction observation and expiration scheduling from the purchase manager's longer workflows. No new architecture layer or pricing/access-policy changes were introduced. Force-unwrap/forced-cast/forced-try audit found none.
- 91 core tests passed and app sources passed iOS SDK type-checking. One intermediate core test run terminated with signal 11, as observed in prior runs; retry passed. This intermittent test-runner failure remains unresolved. Xcode tests could not run because no simulator destination was available. Project/plist and whitespace checks passed.

## Monthly and annual subscriptions — 18 September 2026

- Replaced the lifetime sales offer with auto-renewable monthly (USD 9.99) and annual (USD 39.99, paid yearly) plans in one StoreKit group at the same service level. Existing verified lifetime ownership remains supported but is not offered for sale.
- Paywall shows localized full charges and billing periods, selects annual initially, and displays “Ahorra con el plan anual” only when annual costs less than twelve monthly payments. Added auto-renewal terms, privacy link and Settings subscription management link.
- Entitlement aggregation checks verification, expiration, revocation and upgrades across plans. Transaction updates and an expiration task re-evaluate access; restore/latest-transaction recovery remain supported. Billing Grace Period must remain disabled for this initial configuration; grace extensions are not implemented.
- 91 core tests passed, including pricing/group configuration and expiry/revocation/upgrade policy. One earlier run ended with the previously observed test-runner signal 11; rerun passed. All app sources passed iOS SDK type-checking. Project/plist/whitespace checks passed.
- StoreKit simulator tests were updated for both plans, but could not run because Xcode exposed no available simulator destination. Real checkout, renewal, refunds, plan changes and restoration require sandbox/TestFlight testing before release. App Store Connect products and live Wix pages were not changed; setup instructions are in docs/app-store/connect-setup.md.

## Removed obsolete chat IAP — 18 September 2026

- Deleted the separate chat StoreKit configuration, dedicated UK test scheme, Xcode file reference and unused product identifier. Removed obsolete purchase tests and updated App Store setup instructions. Chat documentation is now `docs/storyteller-chat.md`.
- The only configured product is the one-time library unlock at the local test price of 14.99. A configuration test verifies that single product. No App Store Connect records were changed.
- 90 core tests passed. Project/plist validation, remaining scheme XML validation and whitespace checks passed. Earlier entries below describe historical configurations.

## Completion chat invitation — 18 September 2026

- Completion screens offer “Chat with [storyteller] · 1 doubloon” from 11 completed books onward, linking to that book’s storyteller inside the reader navigation stack. Earlier completions display only the earned coin, without a chat invitation. Existing Settings and bio entry points remain available.
- Eligibility lives in the completion model. Opening chat does not spend a coin; the existing first-successful-reply rule still applies. Review prompting is skipped while navigating into chat.
- 90 core tests passed, including the 10/11 boundary and later/reread completions. All app sources passed iOS SDK type-checking. Visual navigation verification remains pending.

## Earned-doubloon chat sessions — 18 September 2026

- A newly completed distinct book or script earns one doubloon in the same atomic progress save. Repeated completions and matching practice do not grant additional coins. Existing balances are preserved without backfilling historical reads.
- Storyteller Chat is coin-only. Removed its purchase/restore UI and StoreKit dependency from the runtime feature. No coin packs are sold. One validated first reply costs one coin, and subsequent messages remain free for that session.
- Leaving the chat screen, backgrounding the app, or explicitly starting a new topic ends the session. Transcripts are ephemeral; stale requests cannot populate another session. Failed AI responses and failed wallet saves do not spend coins. Existing chat database records are retained but no longer used by the feature.
- 89 core tests passed after replacing superseded chat-purchase tests with coin-session tests. Coverage includes completion idempotency, persisted balances, no-coin access, continuous messages, closed/new sessions, cancellations, invalid replies, failed debits and bounded model context. All app sources passed iOS SDK type-checking; project/plist and whitespace checks passed.
- Live AI, visual behavior and iOS UI tests remain unverified on hardware; no screen control was used. Old chat StoreKit fixtures are historical and must not be submitted as a separate product for this version.

## First ten-day streak gift — 18 September 2026

- The first saved ten-day practice streak earns a single emerald-and-gold VIP theme. An optional, backward-compatible progress flag keeps the earned gift through streak breaks and learning resets. A separate persisted flag prevents repeated completion announcements.
- The gift is shown at the next book completion and remains available in Settings for installation. The existing theme-gift view now supports both single-theme and five-theme rewards. VIP membership still requires 100 distinct books.
- Gift eligibility saves atomically with practice; failed saves grant nothing. Once earned, future progress writes skip the streak reward calculation.
- 96 core tests passed, covering day nine/day ten, failed saves, installation after a broken streak, reload, reset, repeat streaks and no accidental VIP membership. App sources passed iOS SDK type-checking. Visual verification remains pending.

## Installable theme gifts — 18 September 2026

- Library and Midnight are the two initial themes. Storybook (10 books) adds Parchment, Rose, Lavender, Ocean and Forest; Wanderlust (25) adds Terracotta, Honey, Sage, Lagoon and Twilight; Enchanted (50) adds Cherry, Glacier, Pearl, Cocoa and Starlight.
- Shared model catalogue owns milestones, theme identifiers and eligibility. Completion offers a gift; Settings retains earned packs for later. Install persists atomically in SwiftData before themes become selectable, preserves the currently displayed palette, and is idempotent. No downloads, payments or review actions participate.
- Installed packs survive progress reset; earned but uninstalled packs depend on the saved completion count. Existing uninstalled palette preferences fall back to Library until their pack is installed. Additional packs extend the catalogue and palette mapping.
- Native review milestone moved to book 15, separate from the new gift at 10.
- 95 core tests passed, covering milestone boundaries, repeat completions, eligibility, failed installation, idempotence, reload, record round-trip and reset. App sources passed iOS SDK type-checking. All ten new palettes meet 4.5:1 text contrast on paper/surface and primary buttons. Visual simulator verification remains pending.

## Completed Today selection and more books — 18 September 2026

- Completed selections show a tick before Today’s books. Completed focused books also show a title tick and a tick over the storyteller portrait.
- Once the entire selection is complete, the main action becomes a theme-accent outline button labelled “Load 3 more books”. Model-owned selection chooses unread books, saves the new set atomically and keeps completion, vocabulary and reading positions intact.
- Partial remaining sets stay partial across relaunch; exhausted libraries explain that there are no unread books rather than resetting progress. Failed saves retain the completed selection and allow retry. Incomplete selections cannot be replaced by this action.
- 92 core tests passed, including full/partial/exhausted selections, persistence failure, relaunch, empty libraries and purchase access. All app sources passed iOS SDK type-checking. Visual verification remains pending.

## Welcome, lifetime reading numbers and 100-book honours — 18 September 2026

- Updated the welcome heading to the requested Cuentiva introduction.
- Discover numbers new reads from the saved lifetime count of distinct completions; completed selections say “Read again”. No daily numbering reset or duplicate credit.
- Five-book celebration and free-gift announcement are separate tap-driven screens, followed by the wrapped gift, invitation and character setup.
- At 100 distinct saved completions, the completion screen celebrates VIP, Persistence and 1% honours. Stats retains the badges using existing saved progress, including for readers already over 100. The 1% name is explicitly motivational, not a global ranking; no unsupported statistic or book quotation is displayed. Resetting learning progress also resets these honours.
- 89 core tests passed. Tests cover the 99/100 boundary, failed-save rollback, duplicate completion, reload, record round-trip and lifetime numbering. All app Swift sources passed iOS SDK type-checking. Visual simulator validation remains pending.

## Five-book Write milestone and reviews — 18 September 2026

- Write and its library/author links remain hidden until five distinct saved book/script completions. Existing readers with five or more completions already qualify. Reset learning progress also resets this milestone; private story data is not deleted by that reset.
- The fifth completion announces a free gift and waits for a tap. The wrapped-gift screen waits for another tap before revealing the Write invitation, which leads directly into the existing character setup. No gift step advances on a timer. The user receives Write independently of any review. Profile onboarding is deferred until writing is unlocked; generation still requires compatible, available Apple Intelligence.
- A separate native StoreKit review request is eligible at the tenth distinct completion. Repeated books do not trigger either milestone. Apple may suppress the prompt; the app never claims a review was submitted.
- Settings links directly to the review page for Apple ID 6813381807. No review pre-prompt or incentive is used. See https://developer.apple.com/app-store/review/guidelines/ (5.6.1).
- 88 core tests passed, including milestone boundaries, both completion paths, duplicate completion, reload/record encoding, failed-save rollback and the review URL. The initial run hit the previously observed intermittent test-process signal 11; the full retry passed.
- All app Swift sources passed iOS Simulator SDK type-checking. Xcode build-for-testing was blocked by unavailable CoreSimulator runtimes during asset compilation. Visual UI and native review presentation still need simulator/device verification.

## Optional safety audit — 18 September 2026

- Removed forced unwraps from calendar/streak/week calculations, nearby distances, fantasy vocabulary grouping, catalogue URL configuration and the terms link. Invalid download configuration throws an actionable error; calendar failures stop traversal/omit unavailable dates without inventing saved progress.
- Replaced forced test-fixture unwraps with Swift Testing requirements, including audio buffers and calendar fixtures. Re-scanned first-party Swift source/tests for postfix unwraps, try!, as! and implicitly unwrapped optionals; remaining exclamation matches were negation, inequality or string punctuation.
- Added the policy to AGENTS.md and the externally stored cfa-codebase-tidy/SKILL.md at the user-provided path.
- All 85 core tests in 22 suites pass, including missing catalogue address rejection. Swift syntax parse, project/privacy plist checks and diff whitespace checks pass. iOS test execution remains blocked by the unavailable simulator destination/service.
- Skill frontmatter and appended guidance inspected manually. Bundled quick_validate.py could not run because its Python environment lacks PyYAML; no dependency was installed.
- Logs: /tmp/cuentiva-unwrap-final.log and /tmp/cuentiva-unwrap-ios.log.

## KISS review — 18 September 2026

- Reviewed startup coordination, composition, Settings, chat persistence and Discover ordering for unnecessary complexity. Kept access rechecks, persistence boundaries and migration safeguards.
- Simplified recommendation ranking: one Candidate holds each book's computed priority rather than separate rank/arrival/recent lookup tables. Removed forced dictionary unwraps from the sorter. Stable hash caching, daily rotation and recommendation caching remain.
- Added a ranking regression covering personal/new/recent priority and recycling that ignores those boosts, independent of input order.
- All 84 core tests in 21 suites passed. Project/privacy plist validation and whitespace checks passed. Logs: /tmp/cuentiva-kiss-final.log.
- iOS tests remain blocked by unavailable simulator service/destination (/tmp/cuentiva-kiss-ios.log). No full app runtime validation claimed. The test crash recorded in the earlier cleanup has not been explained.

## Storyteller Chat cleanup — 18 September 2026

- Separated bounded request construction from the send workflow; named author, reply and summary limits in ChatLimits. Centralized reply acceptance there and removed the unused StoreKit import from ChatManager. Formatted the chat manager, models, view model and tests.
- Kept access checks around suspension points, cancellation checks, atomic transcript saving and restore behavior unchanged.
- Added integration coverage for seven malformed reply cases preserving existing stored/displayed turns and memory, plus exact response-size boundaries, summary truncation, normalized input and fallback learning level.
- All 83 core tests in 20 suites passed on the first run in this pass. Project/privacy plist checks, Swift syntax parsing and whitespace checks passed. The earlier unexplained test-process crash remains unresolved; this pass did not reproduce it.
- iOS test execution remains blocked by unavailable CoreSimulator destination/service. No full app build or device AI/StoreKit validation claimed.
- Logs: /tmp/cuentiva-chat-cleanup.log and /tmp/cuentiva-chat-cleanup-ios.log.

## Discover cleanup — 18 September 2026

- Extracted daily ranking and its cache into LibraryRecommendationOrder; LibraryManager still owns access, eligibility and saved daily selections. Registered the new file in the app target. Formatted HomeView, HomeViewModel and LibraryManager without intentional UI changes.
- Existing recommendation tests cover cache reuse, daily renewal, new arrivals, old attempts and retained completed cards. Full core suite passes (81 tests); focused FreshLibraryTests passes. Initial full run exited with signal 11 without an assertion failure; rerun passed. This unexplained test-process crash remains an RC investigation item.
- Swift syntax parsing, Xcode source/group membership, project/privacy plist checks and diff whitespace validation passed.
- iOS test attempt could not connect to CoreSimulatorService and could not find the requested destination. No full iOS build or runtime UI validation is claimed.
- Logs: /tmp/cuentiva-tidy-check.log, /tmp/cuentiva-tidy-focused.log, /tmp/cuentiva-tidy-recheck.log, /tmp/cuentiva-tidy-ios.log.

## First release-cleanup pass — 18 September 2026

- RootViewModel owns parallel local loading and entitlement verification through start(). Initial scene activation is ignored for refresh purposes; a real background/foreground cycle refreshes access. Removed the unused progress dependency and renamed the Write tab's internal case.
- Added a regression in the iOS ViewModel test suite for initial activation versus foreground return. This new test has not run here because CoreSimulator is unavailable.
- Formatted the startup, composition, lesson coordination, purchase and storage files with the checked-in swift-format settings. Added the architecture guide, contribution guide and reusable verification script.
- Removed obsolete location-submission permission wording and Xcode-specific purchase-failure advice from production-facing strings. Existing debug-only StoreKit notices remain debug-only.
- Prepared App Store listing/review notes, Wix support/privacy drafts and an explicit submission checklist. No remote app record, IAP product, archive upload or review submission was performed.
- All 81 core tests pass. Swift syntax parsing, project/privacy plist validation and git diff whitespace checks pass. iOS tests cannot find the selected simulator because CoreSimulator services are unavailable. No current physical-device timing or release archive is certified by these checks.

Earlier entries below are historical validation for their respective changes, not proof that the current build has passed all of those device checks.

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

## Community writing links select the tab — 17 September 2026

RootView now owns an explicit selected tab. The community shelf and author
profile share-story buttons invoke the root's Contribute selection instead of
pushing a second contribution screen inside Discover. The existing Contribute
screen and its draft state are reused. Simulator tap verified the writing screen
opened with Contribute visibly selected in the tab bar. Xcode build passed.

## Text-only Wix catalogue and app sync — 17 September 2026

Added a Wix/Velo release service, private-CMS storage adapter, administrator-only
chunked publishing endpoint, publisher CLI, local loopback server and setup guide
under backend/. No Wix files, collections, secrets or publishing were changed;
the user requested code handoff instead of UI-driven deployment.

The app uses bundle/verified-cache-first loading and background HTTPS sync with
1,024-byte response limits, bounded concurrency, SHA-256 checks and atomic cache
replacement. Stable IDs preserve progress without duplicate catalogue entries.
A Settings action exposes update status/retry. Public feed/old release availability,
plan quota limits, absence of member moderation and real location restrictions
are explicitly documented in backend/README.md.

35 Swift core tests and Xcode simulator tests passed. Three backend service tests
passed against all 52 bundled books, including exact Unicode reconstruction,
immutable chunks, incomplete release rejection and unsupported media fields.
The HTTP integration test was attempted but this sandbox denies binding a local
port (listen EPERM 127.0.0.1:8787); it is supplied for local execution. Wix runtime,
secret access, domain routing and live device sync remain unverified until deploy.
