# Cuentiva

[![3 Days of Swift Concurrency — iOS developer training](readme-images/README-Logo-h512.png)](https://www.3daysofswiftconcurrency.com/)

**Bring Spanish to life through stories.**

Cuentiva is a native SwiftUI reading and language-learning app built around short stories, Movie Scripts and verb stories. Read at your own pace, listen to Spanish, practise speaking or writing, and collect the books you complete.

Cuentiva combines a shared reading collection with private, personalised fantasy stories created on the device. Public story submission has been retired. Readers can publish one saved AI tale to their own Discover library every seven days, credited to their personal storyteller; nothing is uploaded. New avatars have an 80% chance of being the fox, with existing avatars preserved. The current iOS 26 demo contains **52 original fictional books** across A1, A2 and B1, with local contribution drafts and example Nearby Stories. The bundled stories are fictional, and personal tales stay on the device.

## Cooperative Feature Architecture (CFA)

Like [Trend](https://github.com/3DaysOfSwift/Trend-iOS-App-Swift-Concurrency-CFA), Cuentiva uses **Cooperative Feature Architecture**: explicit feature boundaries, screen-owned ViewModels and replaceable repositories. The structure helps developers and AI coding assistants see where presentation, business rules and storage belong.

```text
View → ViewModel → Feature API → Feature Manager → Repository
```

Explore the [open-source CFA skills and toolkit](https://github.com/3DaysOfSwift/cooperative-feature-architecture).

## The publisher and its training

[![3 Days of Swift Concurrency — explore the training](readme-images/README-Logo-h512.png)](https://www.3daysofswiftconcurrency.com/)

**[Explore the training at 3DaysOfSwiftConcurrency.com →](https://www.3daysofswiftconcurrency.com/)**

3 Days of Swift Concurrency provides Swift Concurrency training for iOS developers. Cuentiva demonstrates the same approach to SwiftUI, Observation and maintainable feature architecture in a working language-learning app.

## Run

1. Open `Cuentiva.xcodeproj` in Xcode 26.2 or later.
2. Select the **Cuentiva** scheme and an iOS 26 simulator or device.
3. The shared scheme selects `Cuentiva/3 - App Resources/Cuentiva.storekit`. Confirm it under Edit Scheme → Run → Options → StoreKit Configuration.
4. Run. Read or listen to the introductory book, tap Next sentence at your own pace, then Read the full story. Enjoy the extended bilingual reader and use Mark as read at its end. Speak, Write, and Check my words are optional.
5. Continue from the celebration to the subscription offer. Purchase full access in the local StoreKit purchase sheet to unlock the full library.

The StoreKit file configures **$9.99/month and $39.99/year auto-renewable subscriptions** in one group, with no trial. The annual charge is paid yearly. Production App Store Connect setup is still required; display prices come from StoreKit for the user's storefront. Local StoreKit testing does not charge money. Directly launching an installed build outside the Xcode scheme may not connect to local StoreKit. There is no hidden purchase bypass.

For a physical device, select your signing team. The bundle ID is `com.3DaysOfSwiftConcurrency.Cuentiva`; test targets append their target name. All package dependencies are Apple frameworks—there are no third-party dependencies.

## Demo experience

- One free A1 introductory book; onboarding can resume mid-book.
- One-time purchase gate after completion; Restore Purchases is available before and after the introductory lesson.
- Fifty-two bundled books: 46 stories, three Movie Scripts, and three Verbs books across A1, A2, and B1. Each has a typographic cover, aligned bilingual sentences, and a word/lemma index. The three geotagged Thailand examples are discovered through Nearby; the other books appear in Discover.
- Listen with synchronized Spanish text highlighting and a slower playback option.
- On-device Spanish speech recognition when supported; explicit fallback to writing when microphone, permissions, or recognition support are unavailable.
- Writing mode hides the reference sentence and gives aligned word-level feedback. Accents are treated separately; ñ is not treated as n.
- Immediate manual advancement with no mandatory checks, persistent reading progress, and completion celebration. Writing drafts survive tab switches and revisiting sentences during the lesson.
- Completed cover ticks, a separate collection screen, and a counter that counts each book once.
- Weekly streak strip inspired by the requested Trend pattern. A Trend source component was not found, so this is an adaptation, not copied source.
- Private AI tales with Apple Intelligence on supported devices, plus a read-only archive of earlier drafts. No public submission flow.
- Vocabulary states and a settings screen for editing them; exposure marks words learning, never automatically known.
- Settings → Appearance → Colour theme switches between Library and Midnight immediately and remembers the selection across launches. One app-owned ThemeManager supplies the current palette to every screen and sheet.

## Architecture

The Xcode navigator follows CFA's `1 - View`, `2 - AppModel`, `3 - App Resources` structure. A `4 - Swift Extensions` folder will be added only when a reusable extension earns a place.

Each screen owns its adjacent `@MainActor @Observable` ViewModel. Presentation components receive explicit display data or feature inputs; storage stays behind feature APIs. `AppModel.shared` is the production composition root; feature dependencies remain injectable for isolated tests. `AppModel` owns no navigation state.

| Feature | Responsibility |
| --- | --- |
| LibraryManager | Book loading, search, level filtering, vocabulary coverage |
| LearningManager | Access checks, answer comparison, reading progression, optional practice, completion workflow |
| ProgressManager | Committed learner state, streaks, vocabulary evidence, completion counting |
| PurchaseManager | Verified StoreKit ownership, purchase/restore, expiry handling and legacy lifetime recovery, transaction updates |
| PracticeManager | Completed-book practice eligibility, vocabulary statistics, matching glossaries and rewards |
| NearbyManager | Location-based discovery within the selected radius |
| LanguageTermsManager | Searchable bilingual language-term explanations |
| FantasyManager | Private storyteller identity, generated drafts and weekly personal publication |
| ChatManager | Earned-doubloon topic sessions with on-device AI and bounded model context |
| ContributionManager | Legacy draft compatibility; no public submission UI |

Repositories isolate bundled/remote JSON from local SwiftData persistence. Database transactions are atomic and state publishes only after successful persistence. Concurrent progress mutations return a recoverable busy error instead of overwriting one another. Tracked lesson tasks belong to the LessonViewModel; stale audio callbacks are invalidated when a lesson changes. Main-actor managers publish observable state, while decoding and database work happen outside MainActor in repository/model actors.

Speech uses `SFSpeechRecognizer` for short on-device utterances behind a replaceable `LessonAudio` boundary. This demo does not depend on SpeechAnalyzer model downloads. Recognition feedback is not a pronunciation assessment.

## Product rules

- Completed books are unique by stable book ID. Re-reading celebrates practice without incrementing the counter again.
- Next sentence records an encounter and advances after its progress transaction succeeds. The final guided sentence opens the full reader without awarding completion. Mark as read records the continuation and book completion in one atomic save. There is no Skip button or compulsory assessment.
- Advancing a sentence or completing an optional checked attempt qualifies a day for the streak. Opening the app does not.
- Dates use the device's current calendar/time zone when the progress manager is created; stored day keys represent the local date on which practice occurred. Earlier dates are not rebased on travel. The clock/calendar are injectable in tests.
- A verified active subscription unlocks access until its expiry. Existing lifetime purchases remain valid. Refund/revocation locks features without deleting progress. Access is rechecked on StoreKit updates and when returning to the foreground.
- Public submission, publishing goals and contribution eligibility are retired from the app experience.
- Existing local drafts are preserved; new personal tales are saved privately on the device.

## Private writing and legacy drafts

`BookRepository` is the library boundary. `ContributionRepository` currently saves drafts and their local review status. These are legacy records retained for the private draft archive. No remote submission implementation is planned; library delivery remains separate from personal writing.

## Privacy and accessibility

No analytics, ad SDKs, backend calls, or recording storage. Microphone/speech permission is requested only when Speak is selected. On-device recognition is required; there is no silent network fallback. Progress and drafts remain on the device and may be included in device backups. Settings can reset learning progress; deleting the app removes all local app data.

The UI uses Dynamic Type, text/icon feedback rather than colour alone, accessible completion labels, and Reduce Motion for the count animation. Cover height scales with text size. VoiceOver language pronunciation, extreme text sizes, audio interruptions, and device recognition still require hands-on validation.

## Tests

See the [test folder guide](CuentivaTests/README.md) for suite organisation and the
[API coverage audit](CuentivaTests/API-COVERAGE.md) for measured coverage and remaining gaps.
There is one file per view model under `CuentivaTests/ViewModelTests`.

Run the Xcode test target for screen-model and feature tests. The core rules can also run on macOS without a simulator:

```sh
swift test
```

See `VALIDATION.md` for the checks actually completed and remaining device checks. See `Documentation/DECISIONS.md` for the agreed scope and release decisions.

The 15 additional fictional life-skills stories are available in [NEW-STORIES.md](Documentation/NEW-STORIES.md), with editorial sources and scope in [CONTENT-NOTES.md](Documentation/CONTENT-NOTES.md).

The next 14 stories, extracted from a personal journal, are in [JOURNAL-STORIES.md](Documentation/JOURNAL-STORIES.md). [Journal editorial notes](Documentation/JOURNAL-CONTENT-NOTES.md) distinguish book themes, personal interpretations, and checked factual claims.

Six more stories about work, travel, curiosity, and a speculative AI future appear in [WORLD-STORIES.md](Documentation/WORLD-STORIES.md), with editorial notes and cattle terminology sources.

Three factual-science stories with fictional characters are in [SPACE-STORIES.md](Documentation/SPACE-STORIES.md), alongside NASA references.

## Stories and Movie Scripts

The library includes 52 books: 46 stories, three original Movie Scripts, and three Verbs books (A1, A2, B1). Discover and Completed offer All types / Stories / Movie Scripts / Verbs filters, plus library order, English title, difficulty, and book-type sorting. Search and difficulty filtering combine with the format filter.

Scripts show their scene and named speakers. Choose a role or read all roles and advance freely with Next line. After the guided lesson, a full-script reader shows alternating English–Spanish turns and an equally long new continuation (20, 20, and 24 total turns). Slow Spanish audio starts automatically, highlights each word, follows the active turn, and waits one second between speakers. A small toolbar control turns audio off/on. Leaving the reader or backgrounding the app stops playback. The final Mark as read button atomically adds the script to Books Learned; merely finishing the guided lesson or audio does not. The reader stage resumes after reopening. Playback uses the existing single Spanish voice. See [the scripts](Documentation/MOVIE-SCRIPTS.md).

## Extended story reading

All 46 stories have continuations matching their original sentence counts. The original 43-story collection added 370 bilingual pairs, and the three Nearby examples each add eight more. The guided lesson retains its original sentences. Read the full story opens a flowing single-column English–Spanish reader containing both halves, with slow automatic Spanish playback, word highlighting, automatic following, a one-second pause between pairs, and a small audio toggle. Scripts retain their alternating character layout. Both formats share BookReaderViewModel and the same final completion action. Reopening an unfinished book resumes the full-reader stage from its start. Previously earned completions remain intact.

The free café introduction includes its continuation before the purchase gate. Existing sentence IDs and vocabulary lemma mappings are retained. New vocabulary uses curated mappings with surface fallback. All content still needs native-speaker editorial review. Read the [370 new sentence pairs](Documentation/STORY-CONTINUATIONS.md).

## Verbs

Verbs is a third content type in the shared Discover/Completed type picker. The first books are Ser: The letter, Estar: Behind the curtain, and Querer: The last dinner. Each includes 12 guided bilingual sentences and 12 new continuation sentences. Every one of the six present-indicative forms appears in each half. The stories explain meaning through emotional situations, with no conjugation charts. This initial set includes Spain’s vosotros forms; it does not claim to cover all tenses, moods, or regional voseo. Verb books use the story layout, anchored guided Next, full-reader autoplay and final Mark as read. See [the manuscripts](Documentation/VERB-STORIES.md).

## Contribution requests

The topic-request and review workflow is retired. Its models and historical documentation remain for compatibility with earlier local drafts; no submission controls are exposed. Write now creates private personal tales on the device.

## Nearby Stories

Nearby discovers geotagged books within 5, 25 or 100 km, or 1,000 miles (default). Completed stories remain readable after travel. Leaving new public stories at locations is retired. The collection includes three clearly labelled fictional Thailand stories with example locations. See [Nearby Stories](Documentation/NEARBY-STORIES.md) for behavior, privacy and server integration.

## Your turn and Match Pairs

Completed books offer Spanish-only guided rereading, vocabulary statistics and optional matching practice. Match Pairs currently has full glossaries for Ana’s little café and My father’s garden. Each newly completed book awards one persistent doubloon. One doubloon starts a continuous Storyteller Chat session; leaving the chat screen ends it. Matching practice does not award extra coins. See [Your turn](Documentation/YOUR-TURN.md).

## Language help

Settings includes **Decipher language terms**: 12 searchable English–Spanish grammar terms, clear definitions, highlighted examples and related explanations. The word-family statistic opens the lemma entry. This first version is a reference guide, without a quiz.

## A fresh daily library

Discover offers up to three daily reads. Arrival dates are recorded per book on the
reader’s device, so newly downloaded titles lead for 30 days. A corrected pack does
not make an already-known book new again. Within equal arrival/reading/level priority,
a deterministic shuffled order rotates by three positions each local calendar day.

Incomplete books last read today or in the previous three calendar days remain
eligible. Older attempts rest from the default Discover selection but remain
searchable. Legacy attempts without dates are treated as resting. Completed books
are excluded until the eligible collection is exhausted; then recommendations cycle
through the collection again. This never resets completed totals, vocabulary,
streaks, rewards or saved reading positions. Explicit search, sort and completion
filters remain available for browsing.

The editorial target of 1,095 distinct stories provides three stories per day for
365 days. It is a content plan, not a claim that those stories already exist. User
reading, filters, levels and new releases can change the daily recommendations.

## Storyteller characters

Nine permanent illustrated characters guide the collection: Brasa, Musgo, Pipa,
Zumi, Luma, Nube, Tilo, Mora and Faro. Their one-word names, biographies and
bundled portraits appear in the weekly carousel and profile pages. Existing
author IDs are retained; legacy cached profiles resolve to the current cast,
and book-cover credits use the character name. These editorial characters do
not change the people or dialogue inside the stories.

Artwork is bundled locally as 512px JPEGs. Packs carry only text and approved
asset names, never image downloads. Generation prompts are recorded in
[docs/storyteller-art.json](docs/storyteller-art.json). Publish revised packs only
after shipping a client that accepts the new Storyteller asset names.

Today's three are presented in a horizontal carousel. The selection is saved for
that calendar day, including completed cards, so finishing one adds a tick without
replacing it. Opening Discover or returning from a lesson focuses the first unread
book. Swiping or tapping a page indicator selects another book and updates its
details and reading action. The next day's selection uses the existing freshness
rules; permanent completion records are retained.

Local storage uses SwiftData for the catalogue, reading progress, storyteller profile, private stories and drafts. Topic chats live in memory until their screen closes. Existing JSON data is imported once, then obsolete files are deleted after the database has been verified readable. Bundled seed books and GitHub downloads still use JSON. Downloaded catalogues become active on the next launch. See [startup and storage behavior](docs/startup.md).

For contributors, start with [the architecture guide](docs/architecture.md) and [contribution guidelines](CONTRIBUTING.md). Release preparation is tracked in [App Store submission](docs/app-store/README.md).
