# How Cuentiva works

Start with one feature, not the whole project. For reading, follow:

`LessonView → LessonViewModel → LearningManager → ProgressManager → ProgressRepository`

The view displays a sentence and reports a tap. The view model coordinates the screen. LearningManager checks access and asks ProgressManager to record the encounter and next position. The repository saves the changes. Only a successful save changes the confirmed progress and advances the sentence.

## Where code belongs

| Location | Owns | Does not own |
| --- | --- | --- |
| `1 - View/Views/<screen>` | SwiftUI layout and its adjacent observable view model | StoreKit verification, database access, learning rules |
| `1 - View/Components` | Reusable presentation with explicit inputs | Global app state |
| `2 - AppModel/Features/<feature>` | Domain values, feature protocol and manager | Screen layout |
| `2 - AppModel/User Data Storage` | SwiftData, legacy import and catalogue transport | Navigation |
| `2 - AppModel/AppModel.swift` | Construction of the live dependency graph | Work started from an initializer |
| `3 - App Resources` | Seed stories, portraits, icons and local StoreKit fixtures | Real App Store product configuration |

Views create their own view models. View models receive narrow feature protocols through initializers; production defaults come from AppModel. Tests construct independent graphs. Some presentation components accept feature inputs explicitly; there is no need to disguise those dependencies behind another global lookup.

## Startup

RootViewModel owns `start()`. It loads local data and verifies purchases concurrently. The view chooses its destination once local data and the entitlement check are ready. The first scene-activation event does not start another verification. Returning from the background does.

Library sync prepares the next launch's catalogue. Today's screen does not change underneath the reader when a download finishes. Home owns persisting today's recommendations after it mounts. See [startup and storage](startup.md) for migration and caching details.

## Discover recommendations

LibraryManager handles access, available books and today's saved selection. LibraryRecommendationOrder owns deterministic daily rotation, ranking and its in-memory cache. It receives plain values; it performs no persistence or network calls. Unchanged ordering inputs reuse cached IDs while returning the current book values. Date calculations and stable hashes remain outside the sorting comparator.

## Storage

One lazily opened SwiftData container is shared by the live repositories. A model actor owns context operations. Changes save explicitly, and failures roll back. Existing JSON is imported once and removed after a successful database read; normal use writes database records.

The current schema stores small keyed records with binary Codable payloads. Progress is split into positions, encounters, vocabulary, evidence and practice days. Books, stories and chat turns have their own records. This preserves plain Swift domain values and makes migration manageable. It is not a relational model with queryable book-title or vocabulary columns: filtering still happens in feature managers. Introduce typed indexed entities when a demonstrated query need justifies them, rather than claiming this initial schema solves every scaling problem.

## Concurrency and failure

Managers publish UI state on MainActor. Repository actors perform storage and decoding. Async does not automatically make computation cheap: avoid repeated sorting or full-archive encoding during view rendering.

Progress changes are confirmed after a transaction succeeds. Overlapping progress operations currently return a recoverable busy error. Do not replace this with untracked fire-and-forget saves or assume failed writes succeeded. If optimistic navigation is introduced later, it needs a defined retry, flush and failure policy.

## Next cleanup passes

1. Extract Discover recommendation policy from LibraryManager, preserving its day/arrival/level rules with tests.
2. Split the large domain test file into feature suites.
3. Separate active private writing from obsolete contribution rules while preserving old draft decoding.
4. Measure launch, audio teardown and Next sentence on a physical device before changing their execution model.
5. Review large SwiftUI bodies, accessibility and supported iPad layouts one screen at a time.

## Storyteller Chat

ChatManager owns preparation, purchase access, generation and persistence. Its send workflow checks access, builds a bounded request, validates the generated reply, and saves the complete exchange before exposing it. ChatLimits names both input and output limits; the accepted generated summary can be longer than the summary retained for the next request. ChatViewModel owns the composer and its cancellable task. Restore remains independent of loading local chat history or AI availability.
