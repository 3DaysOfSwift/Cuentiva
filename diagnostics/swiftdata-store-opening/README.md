# Isolated SwiftData container-opening crash

Investigation: 19 September 2026. Environment: Apple Silicon, macOS 26.0.1 (25A362), Swift 6.2.3.

## Finding

**Concurrent creation of independent SwiftData ModelContainers for the same model type reproduces the application's intermittent test-process crash.** Each container has its own newly created SQLite URL. The standalone program imports only Foundation and SwiftData: it contains no Cuentiva code, Swift Testing runner, feature managers, repository operations, record inserts or shared user data.

The crash is intermittent and occurs during initial store creation. Representative failing frames match the original test-process report:

```text
EXC_BAD_ACCESS / SIGSEGV
-[__NSDictionaryM setObject:forKey:]
-[NSSQLEntity_DerivedAttributesExtension _generateTriggerSQL]
-[NSSQLiteConnection createTriggersForEntities:]
-[NSSQLiteConnection createTablesForEntities:]
-[NSSQLiteConnection connect]
...
-[NSPersistentStoreCoordinator addPersistentStoreWithType:configuration:URL:options:error:]
```

This establishes the failing operation and a concurrency trigger. It is consistent with unsafe shared metadata mutation in the SwiftData/Core Data initialization path. It does not identify Apple's exact internal faulty statement, establish an Apple-confirmed defect, or prove which other OS versions are affected.

## Controlled experiments

Each process requests 32 separate stores; every trial launches a fresh process. A negative exit code means the child was terminated by that signal.

| Configuration | Fresh processes | SIGSEGV failures |
| --- | ---: | ---: |
| Concurrent opening, versioned schema + migration plan | 25 | 1 |
| Concurrent opening, unique attribute removed | 10 | 3 |
| Concurrent opening, versioned schema without migration plan | 20 | 1 |
| Concurrent opening, plain schema without migration plan | 50 | 4 |
| Container creation serialized through one actor | 80 | 0 |

The baseline consists of five initial trials (the fifth crashed) and twenty confirmation trials. Plain-schema and serial results each combine two batches. Raw exit codes are in [results.json](results.json). These are finite diagnostic observations, not calibrated failure probabilities or proof that serial opening can never fail.

A separate smoke check of the committed harness also reproduced signal 11 on its fifth parallel run; its two serial smoke runs passed. Those checks are recorded separately in results.json and are not included in the table.

Removing uniqueness, versioning or the migration plan does **not** remove the concurrent-opening failure. Therefore deleting those schema capabilities is not a supported fix.

## How the original implementation reached this path

Before the fix, `SwiftDataStore.worker()` coalesced opening within one store instance, then created its container in `Task.detached`. Different SwiftDataStore instances had independent actors/tasks. Parallel tests therefore allowed container initializations to overlap inside one process.

`DatabaseWorker` isolates context access after initialization; it cannot protect initialization happening before that worker exists. Giving every store a separate actor therefore does not prevent this cross-instance startup overlap.

The current `AppModel.live()` shares one SwiftDataStore across its repositories, so the normal app graph does not itself create the same multi-store pattern. The test failure does not prove the shipped iOS app experiences this crash. Direct repository initializers, multiple app graphs, or future independent stores can still create that pattern. This investigation ran on macOS; iOS remains unverified.

## Applied mitigation (original candidate evidence)

A private shared `StoreOpener` actor performs directory/schema/configuration/container creation and constructs DatabaseWorker in one synchronous actor method, with no suspension inside it. Each SwiftDataStore still coalesces its own opening task and retries failed openings. Ordinary reads, writes, feature operations and tests remain independently concurrent.

The initial candidate experiment used **a temporary copy of the project**:

- Initial candidate build/test: 111 tests passed.
- Twenty further full-suite runs, with normal parallel test execution: all 111 passed each time (2,220 test executions).
- During that initial experiment, production Swift source was unchanged and test parallelism remained enabled.

The original tested source difference is [candidate-opening-gate.patch](candidate-opening-gate.patch), retained as investigation evidence. The opening actor is now applied to production, with explicit store injection required by repositories. Three opening/isolation/retry regressions were added. The current 114-test parallel suite passed once after building and in 10 further fresh-process runs, without crashes. App and test sources pass iOS SDK type-checking; device/simulator runtime validation remains outstanding. The production database path, schema and migration behaviour are unchanged.

## Reproduce without touching app data

From the repository root:

```sh
python3 diagnostics/swiftdata-store-opening/run.py --mode parallel --rounds 20
python3 diagnostics/swiftdata-store-opening/run.py --mode serial --rounds 20
```

The harness compiles the standalone Swift program, uses fresh temporary store directories and stops at the first failed child process. It removes its store directories even when the child crashes. It retains compiler logs, per-run logs and results in the temporary output folder printed at the start. It never opens the application's database. Normal parallel runs may all pass because the failure is intermittent. System crash reports may also appear in `~/Library/Logs/DiagnosticReports`.

The executable's `serial` option serializes **only container creation**, not the whole diagnostic or the application's test suite. The first investigation used equivalent binaries for the schema variants in the table. The committed minimal program retains the production-style schema so the parallel/serial comparison stays small and readable.

Representative original system reports:

- `swiftpm-testing-helper-2026-09-19-083025.ips` — full test suite.
- `repro-2026-09-19-131119.ips` — standalone baseline.
- `no-unique-2026-09-19-131208.000.ips` — no unique constraint.
- `versioned-no-plan-2026-09-19-131305.ips` — no migration plan.
- `no-migration-2026-09-19-131430.0003.ips` — plain schema.

These local reports were inspected for matching stacks. Full reports are not copied into the repository because they include machine-specific metadata.
