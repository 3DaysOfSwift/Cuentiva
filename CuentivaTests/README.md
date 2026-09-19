# Cuentiva tests

Tests are grouped by responsibility. Production behaviour belongs to the feature managers; view-model tests check the state and actions presented to a screen.

| Folder | What it verifies | Runs in |
| --- | --- | --- |
| `AppModelTests` | Dependency wiring and shared access/progress through an isolated AppModel | Xcode |
| `PresentationTests/ViewModelTests` | One `NameViewModelTests.swift` per view model: screen state, actions, errors and cancellation | Xcode |
| `AppModelTests/FeatureTests/<Feature>` | Feature APIs, domain rules, access gates and rewards | Swift package and Xcode |
| `AppModelTests/ConcurrencyTests` | Ordering, overlapping operations, cancellation and shared refreshes | Swift package and Xcode |
| `AppModelTests/PersistenceTests` | Real temporary SwiftData stores, catalogue sync, migration and atomic rollback | Swift package and Xcode |
| `PresentationTests` | Theme selection and presentation-specific state | Xcode |
| `IntegrationTests/Shared` | Workflows spanning several model features | Swift package and Xcode |
| `IntegrationTests` (other files) | Screen coordination, speech adapters and StoreKit sandbox integration | Xcode; StoreKit requires simulator |
| `Support` | Sample data, in-memory repositories and fixture paths; no test cases | Both; `Support/iOS` is Xcode-only |

## Running the tests

In Xcode, select the **Cuentiva** scheme and an iPhone simulator, then press **Command-U**. Every Swift file in these folders belongs to the CuentivaTests target. Code coverage is enabled on the shared scheme; inspect the test report's Coverage tab. StoreKit tests use the bundled local configuration and do not make real purchases.

For model tests without a simulator, run from the repository root:

```sh
swift test --enable-code-coverage
```

This tests `CuentivaAppModel`, using the same model sources as the app. It excludes AppModel's live composition, the views/view models, and Apple-specific audio, location and AI adapters. A passing package run does **not** mean the iOS tests passed.

To find SwiftPM's machine-readable coverage report:

```sh
swift test --show-codecov-path
```

## Adding tests

- Put screen tests beside the matching view-model test suite. Keep one file per production view model; parameterized tests may cover a matrix of inputs.
- Group feature scenarios under the corresponding feature folder. Prefer observable outcomes over checks of private implementation details.
- Test a meaningful success path and applicable failure, boundary, repeat, cancellation and overlap cases. A test that merely invokes each function is not complete coverage.
- Inject independent feature graphs. Never use `AppModel.shared` or default production dependencies in a unit test.
- Own one temporary SwiftData store per isolated test graph and inject it into its repositories. Never share a store across independent scenarios. Use isolated UserDefaults suites. Clean them up when the test finishes.
- Use controlled gates for asynchronous work, not arbitrary sleeps. Bound waits so a broken operation produces a failure instead of hanging indefinitely.
- Use `try #require` for necessary fixtures, never force unwraps or intentional traps.
- Add new Swift files to the Xcode test target as well as the filesystem. Keep platform-only files excluded in Package.swift.

See [API-COVERAGE.md](API-COVERAGE.md) for measured model coverage, API responsibilities and remaining gaps. That document is a dated audit, not a promise that every possible state has been tested.
