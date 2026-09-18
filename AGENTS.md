# Cuentiva development

Use Cooperative Feature Architecture. Preserve the numbered Xcode folder layout.
Each screen owns one adjacent @MainActor @Observable ViewModel through @State.
ViewModels depend on narrow replaceable feature APIs. AppModel.shared is the
production composition root; test graphs must remain independent.
Business rules and workflow decisions belong to feature managers. Repositories
own external storage details. Preserve atomic persistence, duplicate-safe book
completion, and the single-free-book purchase gate. Do not move rules into
Views or fabricate live AI, publishing, or StoreKit entitlement success.

Use `com.3DaysOfSwiftConcurrency.Cuentiva` for the app and append test target
names for test bundle identifiers. This is a real Xcode app, not a Playground.

Run core tests (`swift test`) and relevant Xcode tests after behavioral changes.
Record runtime validation limits honestly. Production product setup, brand clearance,
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

During every cleanup, audit first-party Swift source and tests for forced unwraps,
implicitly unwrapped optionals, `try!` and `as!`. Remove them using nonoptional APIs
or explicit safe checks and error handling. Never substitute traps, fabricated
success or arbitrary defaults. Use `try #require` for required test fixtures.
