# Cuentiva development

## Coding agreement

Apply these rules to first-party Swift source and tests on every coding task.
Before changing an area, read its linked section in the [Swift coding guide](Documentation/SwiftCodingGuide.md).
Apply changes within the requested scope; read-only reviews report findings.

1. **Crash safety.** Treat force unwraps as deliberate `fatalError()` decisions,
   never shortcuts. Do not introduce `!`, IUOs, `try!`, `as!` or replacement traps
   to avoid handling failure. Use nonoptional APIs or explicit safe handling;
   defaults must represent valid behaviour. Never invent a reason to terminate.
   Audit touched code and tests; during cleanup audit all first-party Swift.
   Use `try #require` for required test fixtures. [Guide §1](Documentation/SwiftCodingGuide.md#1-force-unwrapping-means-choosing-a-crash).
2. **Model-owned decisions.** Put shared business rules, validation, access,
   rewards and policies in model features for all current and future targets.
   Enforce them through feature APIs even when the UI disables an action.
   Repositories own storage/transport; ViewModels own presentation state.
   [Guide §2](Documentation/SwiftCodingGuide.md#2-shared-decisions-belong-in-the-model).
3. **Declarative Views.** Views describe content and forward intent. Move
   multi-step presentation workflows to the adjacent ViewModel; business work
   stays in features. Simple bindings and lifecycle forwarding may remain in
   Views without extra abstraction. [Guide §3](Documentation/SwiftCodingGuide.md#3-swiftui-views-describe-the-interface).
4. **KISS.** Prefer clear names, existing patterns and the smallest sufficient
   change. Add types/protocols for real responsibilities or dependencies.
   Keep one authoritative source of state; derive other values and make cache
   invalidation explicit. [Guide §4](Documentation/SwiftCodingGuide.md#4-prefer-a-straightforward-solution).
5. **Honest persistence.** Commit before reporting saved success. Preserve data,
   rollback, retry and duplicate protection. Never overwrite unreadable data
   with empty defaults or hide significant errors with `try?`. Intentional
   optimistic UI needs pending state and rollback. Cancellation is not success.
   [Guide §5](Documentation/SwiftCodingGuide.md#5-fail-honestly-and-preserve-saved-data).
6. **Concurrency ownership.** Give tasks owners and cancellation lifetimes.
   Use structured concurrency where appropriate and worker actors for expensive
   work; `Task` alone does not move it off MainActor. Define overlap/ordering
   policy, account for actor reentrancy, and reject stale results after awaits.
   Avoid blocking waits and detached tasks used to bypass isolation errors.
   [Guide §6](Documentation/SwiftCodingGuide.md#6-make-concurrency-ownership-explicit).
7. **Responsive launch.** Show prepared local data promptly. Separate routine
   reads from writes/migrations; perform unrelated downloads and preparation in
   the background with an explicit activation point. Measure necessary waits
   and device latency outside the debugger before diagnosing bottlenecks.
   [Guide §7](Documentation/SwiftCodingGuide.md#7-keep-launch-and-interactions-responsive).
8. **Behavioural tests.** Test feature decisions and ViewModel outcomes using
   isolated injected dependencies. Cover relevant failure, retry, cancellation,
   overlap and stale-result cases with controlled gates and bounded waits.
   Run focused tests, `swift test`, and relevant Xcode tests/builds. Distinguish
   parsing, type-checking and runtime validation; report blockers and every
   recurring crash. A passing rerun does not explain a crash.
   [Guide §8](Documentation/SwiftCodingGuide.md#8-test-behaviour-and-state-the-limits).
9. **One SwiftData container.** AppModel owns one shared ModelContainer and
   persistent store; inject it into all repositories with no fallback creators.
   Models/collections and actor-owned contexts share it. Preserve store path,
   schema and user data. Concurrent container initialization reproduced fatal
   Core Data SIGSEGV even with separate files; per-store actors do not prevent
   that overlap. Open off MainActor, coalesce requests, and use the shared
   serial opener for independent test containers without serializing tests or
   ordinary operations. Keep managed objects actor-local. Any store exception
   needs explicit justification and user agreement. Read the [warning and
   safeguards](Documentation/SwiftCodingGuide.md#9-swiftdata-one-app-owned-persistent-store)
   and [reproduction evidence](diagnostics/swiftdata-store-opening/README.md).

Keep this agreement aligned with the canonical CFA guide as lessons are added.
Keep explanations and examples in the guide; essential rules remain here.

## Project conventions

Use Cooperative Feature Architecture. Preserve the numbered Xcode folder layout.
Each screen owns one adjacent @MainActor @Observable ViewModel through @State.
ViewModels depend on narrow replaceable feature APIs. AppModel.shared is the
production composition root; test graphs must remain independent.
Preserve atomic persistence, duplicate-safe book completion, and the single-free-book
purchase gate. Never fabricate live AI, publishing or StoreKit entitlement success.

Use `com.3DaysOfSwiftConcurrency.Cuentiva` for the app and append test target
names for test bundle identifiers. This is a real Xcode app, not a Playground.

Production product setup, brand clearance,
content review, and backend publishing are intentionally unresolved.

Keep exactly one app-owned ThemeManager in its own file under `1 - View/Theme`.
Provide at least two complete palettes and a persistent Settings selector. Every
screen and presentation uses the selected palette; do not force light appearance
or hard-code UI surface/text colours outside the theme definitions.

Keep independent reusable views in their own named files. Do not hide unrelated
components such as streak indicators or error messages in another view’s file.

Language help must explain terms without assuming prior grammar knowledge. Start
with a familiar situation, show what each example word does, and translate Spanish
examples. Explain any necessary technical term where it appears; related-term links
are optional exploration, never prerequisites for understanding the current entry.
Prefer one clear idea at a time over lists of classifications and exceptions.
Clearly distinguish words being discussed from the surrounding explanation using
quotation marks and selective bold emphasis. Keep short paragraphs intact when
rendering formatted teaching copy.
