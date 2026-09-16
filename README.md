# Cuentiva

Learn Spanish through community-written stories about real people.

A native SwiftUI iOS 26 demo using Cooperative Feature Architecture (CFA), Swift 6, and Apple speech/audio frameworks. The five bundled stories are original fictional demonstration content, clearly labelled as such; they are not verified community memoirs.

## Run

1. Open `Cuentiva.xcodeproj` in Xcode 26.2 or later.
2. Select the **Cuentiva** scheme and an iOS 26 simulator or device.
3. The shared scheme selects `Cuentiva/3 - App Resources/Cuentiva.storekit`. Confirm it under Edit Scheme → Run → Options → StoreKit Configuration.
4. Run. Read or listen to the introductory book, tap Next sentence at your own pace, then tap Finish book. Speak, Write, and Check my words are optional.
5. Continue from the celebration to the subscription offer. Start the trial in the local StoreKit purchase sheet to unlock the full library.

The StoreKit file uses **$4.99/month as a test-only placeholder**, with a one-week introductory offer. Production pricing has not been decided. Local StoreKit testing does not charge money. Directly launching an installed build outside the Xcode scheme may not connect to local StoreKit and will show purchase options unavailable. There is no hidden subscription bypass in the app.

For a physical device, select your signing team. The bundle ID is `com.3DaysOfSwiftConcurrency.Cuentiva`; test targets append their target name. All package dependencies are Apple frameworks—there are no third-party dependencies.

## Demo experience

- One free A1 introductory book; onboarding can resume mid-book.
- Subscription gate after completion; Restore Purchases is available before and after the introductory lesson.
- Five searchable books: two A1, two A2, one B1. Each has a typographic cover, aligned bilingual sentences, and a word/lemma index.
- Listen with synchronized Spanish text highlighting and a slower playback option.
- On-device Spanish speech recognition when supported; explicit fallback to writing when microphone, permissions, or recognition support are unavailable.
- Writing mode hides the reference sentence and gives aligned word-level feedback. Accents are treated separately; ñ is not treated as n.
- Immediate manual advancement with no mandatory checks, persistent reading progress, and completion celebration. Writing drafts survive tab switches and revisiting sentences during the lesson.
- Completed cover ticks, a separate collection screen, and a counter that counts each book once.
- Weekly streak strip inspired by the requested Trend pattern. A Trend source component was not found, so this is an adaptation, not copied source.
- Contribution drafts, preview, local coaching prompts, and local pending-review submissions. No uploads or live AI are claimed.
- Vocabulary states and a settings screen for editing them; exposure marks words learning, never automatically known.
- Settings → Appearance → Colour theme switches between Library and Midnight immediately and remembers the selection across launches. One app-owned ThemeManager supplies the current palette to every screen and sheet.

## Architecture

The Xcode navigator follows CFA's `1 - View`, `2 - AppModel`, `3 - App Resources` structure. A `4 - Swift Extensions` folder will be added only when a reusable extension earns a place.

Each screen owns its adjacent `@MainActor @Observable` ViewModel. Views do not receive managers, repositories, or ViewModels. `AppModel.shared` is the production composition root; feature dependencies remain injectable for isolated tests. `AppModel` owns no navigation state.

| Feature | Responsibility |
| --- | --- |
| LibraryManager | Book loading, search, level filtering, vocabulary coverage |
| LearningManager | Access checks, answer comparison, reading progression, optional practice, completion workflow |
| ProgressManager | Committed learner state, streaks, vocabulary evidence, completion counting |
| PurchaseManager | Verified StoreKit entitlements, introductory eligibility, purchase/restore, transaction updates |
| ContributionManager | Demo eligibility, draft validation, submission and coaching rules |

Repositories isolate bundled JSON and actor-protected local persistence. Writes are atomic and state publishes only after successful persistence. Concurrent progress mutations return a recoverable busy error instead of overwriting one another. Tracked lesson tasks belong to the LessonViewModel; stale audio callbacks are invalidated when a lesson changes. Main-actor managers publish observable state, while file decoding and writes happen in repository actors.

Speech uses `SFSpeechRecognizer` for short on-device utterances behind a replaceable `LessonAudio` boundary. This demo does not depend on SpeechAnalyzer model downloads. Recognition feedback is not a pronunciation assessment.

## Product rules

- Completed books are unique by stable book ID. Re-reading celebrates practice without incrementing the counter again.
- Next sentence records reading completion and advances immediately. Finish book records the final sentence and book in one atomic save. There is no Skip button or compulsory assessment.
- Advancing a sentence or completing an optional checked attempt qualifies a day for the streak. Opening the app does not.
- Dates use the device's current calendar/time zone when the progress manager is created; stored day keys represent the local date on which practice occurred. Earlier dates are not rebased on travel. The clock/calendar are injectable in tests.
- Trial cancellation preserves access until the entitlement expires. Expiration locks features without deleting progress. Active app access is rechecked every 30 seconds, on StoreKit updates, and when returning to the foreground.
- Demo contribution unlock: active membership plus one completed book. This is explicitly not a CEFR assessment. Real proficiency-based eligibility remains a product decision.
- Only published contributions count toward the goal of five. The local demo never invents publication approval.

## Wix later

`BookRepository` is the library boundary. `ContributionRepository` currently saves drafts and their local review status. A remote implementation will require an agreed authenticated API and server-authoritative review status, not just filling in a URL. Add a dedicated submission command/response when the server contract exists. Keep administrative credentials and moderation permissions on the server. The UI does not need to know Wix paths or CMS record formats.

## Privacy and accessibility

No analytics, ad SDKs, backend calls, or recording storage. Microphone/speech permission is requested only when Speak is selected. On-device recognition is required; there is no silent network fallback. Progress and drafts remain on the device and may be included in device backups. Settings can reset learning progress; deleting the app removes all local app data.

The UI uses Dynamic Type, text/icon feedback rather than colour alone, accessible completion labels, and Reduce Motion for the count animation. Cover height scales with text size. VoiceOver language pronunciation, extreme text sizes, audio interruptions, and device recognition still require hands-on validation.

## Tests

Run the Xcode test target for screen-model and feature tests. The core rules can also run on macOS without a simulator:

```sh
swift test
```

See `VALIDATION.md` for the checks actually completed and remaining device checks. See `Documentation/DECISIONS.md` for the agreed scope and release decisions.
