> Reference copy of the CFA toolkit’s `architecture/swift-coding-guide.md`.
> Update the canonical toolkit guide first, then refresh this copy.

# Swift coding guide

Our working principles for readable, dependable Swift. This is a living guide: add rules when they solve a demonstrated problem, explain their purpose, and keep examples small. It applies to first-party source and tests across the CFA toolkit. It is an engineering standard, not a claim that Swift itself forbids these constructs.

Creation follows these rules from the start. Adoption, migration and tidying apply them within the requested scope. Read-only reviews report violations and suggested corrections without editing code. Preserve existing architecture during concurrency-only migration; shared model rules do not require adopting CFA type names.

## 1. Force unwrapping means choosing a crash

**Rule:** Do not use the force-unwrap operator unless it is deliberately considered a shorthand replacement for `fatalError()`. Treat every occurrence as an explicit crash decision, never as a convenient way to access an optional.

Swift's documentation states: “The ! is, effectively, a shorter spelling of fatalError(_:file:line:).” A non-nil value unwraps; nil traps. The analogy describes failure behaviour, not an unconditional crash.

[Reference: The Swift Programming Language — Force Unwrapping](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Force-Unwrapping)

For commercial application code, the default is to remove forced operations. An apparently constant value, a preceding check, or passing tests does not justify an exception. If termination is truly the intended product behaviour for an unrecoverable invariant, explicitly document that decision, its owner and why recovery is inappropriate. Agents must not invent this intent to retain an unwrap. Prefer an explicit, diagnostic fatal error over concealing a deliberate termination in `!`.

Apply the same scrutiny to implicitly unwrapped optionals, `try!` and `as!`. Do not replace them with another trap, arbitrary fallback values or fabricated success.

```swift
// Unsafe: malformed input terminates the app.
let quantity = Int(input)!

// Safe: the caller can explain and recover from invalid input.
guard let quantity = Int(input) else {
    throw OrderError.invalidQuantity
}
```

Use nonoptional APIs where possible. Iterate dictionary entries rather than force-looking up their keys. Use optional binding, optional chaining or safe casts when absence is meaningful. Use `??` only when the fallback is valid behaviour. In tests, `try #require(optionalValue)` produces a useful failure diagnostic instead of a process crash.

**Review:** Search source and tests for forced operations, distinguish them from negation and string punctuation, and inspect interpolation expressions. Verify failure handling preserves existing data and does not falsely report success.

## 2. Shared decisions belong in the model

**Rule:** Keep decisions needed by all targets—including future targets—in the model, not Views or ViewModels.

“Model” means the domain layer: feature managers, policies and domain values. It does not mean putting every function in a single model object. Repositories own storage and transport implementation details.

A purchase entitlement, publishing allowance, validation rule, recommendation policy or completion reward must behave identically from an iPhone screen, a future Mac app or another entry point. The feature must enforce it even if the UI also disables a button.

```swift
// ViewModel: forward intent and present the outcome.
func publish() async {
    do {
        try await stories.publish(draft)
        message = "Added to your library."
    } catch {
        self.error = error.localizedDescription
    }
}

// Story feature: enforce entitlement and weekly allowance here,
// then save before making the new publication visible.
```

ViewModels own presentation state: drafts, focus, selection, navigation, loading indicators and user-facing messages. They coordinate with feature APIs; they do not duplicate domain decisions. Derived presentation values may stay there.

**Review:** Would another target have to copy this decision to behave correctly? If so, put it in the owning feature and test it through that feature's public API.

## 3. SwiftUI Views describe the interface

**Rule:** Keep Views declarative and free of imperative workflows in almost all cases. Move multi-step event handling into the ViewModel belonging to that View.

```swift
// View: describe the control and forward intent.
Button("Save", action: viewModel.save)

// ViewModel: own the event task and presentation transitions.
func save() {
    guard saveTask == nil else { return }
    saveTask = Task {
        defer { saveTask = nil }
        do {
            try await feature.save(draft)
            message = "Saved."
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

The example assumes a ViewModel-owned task property and explicit feature dependency. Choose cancellation and lifetime for the actual operation; a persistent save need not be cancelled just because the screen disappears. Business rules within `feature.save` remain in the model.

Bindings, conditional content, `ForEach`, direct dismissal and lifecycle glue such as `.task { await viewModel.load() }` are declarative UI work. UIKit delegate and layout code belongs in a named presentation adapter when needed. Do not create extra layers just to move a trivial assignment.

**Review:** A reader should see what the screen displays and which intents it forwards without tracing storage calls, business rules or multi-step tasks in its body.

## 4. Prefer a straightforward solution

**Rule:** Apply KISS: choose the smallest clear design that meets the real requirements.

Prefer explicit names and sequential steps over clever chains, nested ternaries and unexplained constants. A short function is not automatically clear; a longer function is not automatically complex. Introduce a helper, protocol or type when it owns a cohesive concept or a real dependency boundary—not for each line of code or a hypothetical future framework.

Keep one authoritative source of each piece of state. Derive values instead of storing redundant flags unless a measured cache needs them. Keep cache invalidation inputs explicit. Avoid broad rewrites when a small correction addresses the problem.

**Review:** Can a new reader identify the inputs, decision, state changes and outcome without following unnecessary indirection?

## 5. Fail honestly and preserve saved data

**Rule:** Handle errors at the layer that can make a meaningful decision. Report success only after the operation succeeds.

Do not turn unreadable saved data into an empty collection that will overwrite the original. Do not use `try?` to hide a failed purchase, save or migration. Optional best-effort work may use it only when failure is deliberately harmless and understood.

For persistence, prepare the proposed state, commit it, then expose confirmed success. Preserve rollback, retry and duplicate protection. If optimistic UI is intentional, define rollback and make pending state distinguishable from saved state. Cancelled work should not appear as a successful result.

**Review:** Exercise failed writes and retries. Confirm neither progress nor rewards are silently lost or duplicated.

## 6. Make concurrency ownership explicit

**Rule:** Use Swift concurrency with a clear task owner and a deliberate policy for overlapping work.

Use structured child tasks for independent work whose lifetime belongs to the current operation. Give longer-lived tasks an owner and cancellation policy. A `Task` does not automatically move expensive work off the main actor; use suitable actor workers for parsing, persistence and generation. Do not add detached tasks merely to silence isolation errors.

Actors protect isolated state, but an `await` permits reentrancy. Decide whether overlapping operations are rejected, coalesced, serialized or allowed independently. Recheck relevant access and request identity after suspension before publishing results. Avoid blocking waits and replacing GCD mechanically without preserving its ordering guarantees.

**Review:** Test cancellation, overlap, stale completion and retry with controlled dependencies rather than sleeps or scheduler assumptions.

## 7. Keep launch and interactions responsive

**Rule:** Display already prepared local data promptly. Keep unrelated downloads and preparation off the critical user interaction path.

Separate ordinary reads from writes and migrations. One-time migration may need to finish before affected data is usable; name and measure that cost. Load independent prerequisites concurrently when safe. Background updates should have a clear activation point so content does not unexpectedly change beneath the user.

Measure cold launch, warm launch and interaction latency on a physical device outside the debugger. Do not diagnose a bottleneck from one broad timer or assume a new storage framework fixes it.

**Review:** Identify what the screen actually waits for and record evidence before optimizing.

## 8. Test behaviour and state the limits

**Rule:** Test observable outcomes and important failure paths, not the implementation's spelling.

Use injectable dependencies and synthetic data. Cover feature decisions and ViewModel presentation behaviour at their respective boundaries. Use controlled continuations for concurrency tests, with bounded waits and cleanup. Required fixtures should fail explicitly rather than crash or silently skip assertions.

Run focused tests, then the relevant wider suite and build. Source parsing is not type checking; a core suite is not device UI, StoreKit or AI validation. Record failures, skips and environment blockers accurately. A passing rerun does not explain an earlier crash.

**Review:** Can the evidence support the specific claim being made about correctness or readiness?

## 9. SwiftData: one app-owned persistent store

Use **one shared ModelContainer backed by one persistent SwiftData store per iOS app**, owned by the production
AppModel composition root. Features keep their records in separate model types
or logical collections inside that store. A feature boundary is not a database
boundary. This is our architecture convention, not a limitation of SwiftData.

- Create the store once and inject it into every persistent repository. Make
  that dependency mandatory: no optional store arguments, hidden fallback
  containers, or per-feature database files.
- Keep schema, configuration, database location and lifetime in the model's
  persistence layer. Views and ViewModels do not create or choose stores.
- Multiple actor-owned contexts may use the same container. Keep each context
  and its managed objects within its owner; pass Sendable values across actors.
  A separate context does not require a separate persistent store.
- Open lazily off MainActor and coalesce overlapping requests. Serialize
  container creation across independent graphs where required to avoid the
  observed Core Data initialization race. Do not serialize the entire test
  suite or unrelated database operations as a workaround.
- Each persistence test graph owns an isolated temporary store. Share it among
  that graph's repositories, never across unrelated tests. Domain tests can use
  in-memory repository doubles without constructing SwiftData containers.
- Preserve the existing production store path and schema when refactoring
  ownership. If multiple shipped stores really exist, migrate and verify their
  data before removing anything; never silently discard user records.

### Crash warning: overlapping container initialization

Concurrent creation of independent `ModelContainer` instances for the same model
type reproduced an intermittent **EXC_BAD_ACCESS / SIGSEGV process crash** in our
standalone SwiftData investigation (macOS 26.0.1, Swift 6.2.3, September 2026).
The containers used separate fresh SQLite files. The failing stack included
Core Data's `_generateTriggerSQL`, `createTriggersForEntities:` and mutable
Dictionary insertion during initial store creation, before any record writes.

The evidence is consistent with a race involving shared framework metadata
while containers initialize. The exact internal cause is not Apple-confirmed;
we have not established which other OS versions, including iOS, are affected.
Multiple containers are supported by SwiftData in general: their existence
alone is not proof of a crash. **Overlapping initialization was the reproduced
trigger.** A SIGSEGV cannot be recovered with Swift `do`/`catch`.

**Primary prevention: do not create multiple containers in the live app graph.**
Create one at the composition root and inject the same owner into every
repository. A single database filename is not enough if each repository still
constructs its own container. Separate models, collections and actor-owned
contexts can share that one container.

Hidden fallback constructors, repeated app graphs and parallel persistence tests
can reintroduce overlapping initialization. Separate actors for separate stores
only isolate each instance; they do not coordinate initialization across them.
Likewise, a worker actor created after the container cannot protect its creation.

When isolated test graphs legitimately need independent containers, route their
creation through one shared off-main-actor opener, with no suspension during
container creation. Coalesce concurrent opening requests within each store.
Keep tests parallel and normal operations on their own worker actors. Moving
creation into detached tasks alone does not prevent this race. Do not work
around it by removing uniqueness constraints or migration/versioned schemas:
those variants also crashed in the investigation.

Serialized-opening controls and repeated parallel-suite runs passed without
this crash; finite passing runs are evidence for the mitigation, not a guarantee
against every framework failure. Preserve the reproducer and report any
recurrence with the OS version, stack and opening pattern. Validate on the
supported iOS runtime before release.

During review, locate every container/store constructor and verify that only
composition roots and the persistence factory create them. Test concurrent
opening, failure recovery, collection isolation and persistence after reopening.
Any exception to the one-store rule needs an explicit architectural reason and
user agreement; adding a feature is not sufficient justification.

## Evolving this guide

For each new principle, include the rule, reason, preferred approach, a small example when useful, and a review check. Cite official sources for language semantics. Distinguish our engineering preferences from language requirements. Keep this file canonical; update bundled skill copies through the toolkit's sync script.
