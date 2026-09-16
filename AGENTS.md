# Cuentiva development

Use Cooperative Feature Architecture. Preserve the numbered Xcode folder layout.
Each screen owns one adjacent @MainActor @Observable ViewModel through @State.
ViewModels depend on narrow replaceable feature APIs. AppModel.shared is the
production composition root; test graphs must remain independent.
Business rules and workflow decisions belong to feature managers. Repositories
own external storage details. Preserve atomic persistence, duplicate-safe book
completion, and the single-free-book subscription gate. Do not move rules into
Views or fabricate live AI, publishing, or StoreKit entitlement success.

Use `com.3DaysOfSwiftConcurrency.Cuentiva` for the app and append test target
names for test bundle identifiers. This is a real Xcode app, not a Playground.

Run core tests (`swift test`) and relevant Xcode tests after behavioral changes.
Record runtime validation limits honestly. Production price, brand clearance,
content review, and backend publishing are intentionally unresolved.

Keep exactly one app-owned ThemeManager in its own file under `1 - View/Theme`.
Provide at least two complete palettes and a persistent Settings selector. Every
screen and presentation uses the selected palette; do not force light appearance
or hard-code UI surface/text colours outside the theme definitions.

Keep independent reusable views in their own named files. Do not hide unrelated
components such as streak indicators or error messages in another view’s file.
