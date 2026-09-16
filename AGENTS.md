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
