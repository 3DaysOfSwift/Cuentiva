# Validation — 16 September 2026

## Completed

- Xcode 26.2, Swift 6 strict-concurrency compilation: **passed**.
- Generic arm64 iOS Simulator `build-for-testing`: **passed**, including the app and iOS test bundle.
- macOS core test execution: **15 tests passed** in four suites.
- Core coverage includes edit-distance alignment, accent and ñ handling, duplicate completion, partial lessons, subscription gating, streak day boundaries, vocabulary evidence, collection filtering, local review states, bundled content indexing, atomic disk round trips, and corrupt-file error handling.
- Eight screen-model tests are included and compiled in the iOS test target. They were not executed here.
- Five bundled books validate as aligned bilingual sentence records with indexed vocabulary counts.

## Environment limits

Simulator services were inaccessible in this Codex session. Additional Simulator/cache filesystem permissions were requested but not granted. Consequently, the app has not been launched or visually inspected in Simulator, and the iOS tests, local StoreKit purchase dialogs, and microphone path have not been runtime-tested here.

For compiler verification in this nested sandbox, the invocation used the Swift compiler's `-disable-sandbox` helper flag; the enclosing workspace sandbox remained in force. That environment-only flag is not saved in the Xcode project. Build/cache files are outside the deliverable repository.

## Hands-on verification in Xcode

1. Run the Cuentiva scheme with its StoreKit file selected. Complete onboarding with writing, then confirm the celebration and paywall appear.
2. Decline the offer; confirm no library, completed shelf, or contribution access. Restore remains available.
3. Start the local seven-day trial. Confirm all five books appear and the introduction already has its completion tick.
4. Search and filter A1/A2/B1. Complete another book; verify one new counter increment and its appearance in Completed.
5. Relaunch during a lesson; verify saved position and attempts. Repeat a completed book; verify no duplicate counter increment.
6. Use Xcode's StoreKit transaction manager to expire/refund the subscription. Confirm the feature gate returns and preserves progress. Restore an active subscription; confirm the shelf returns. Verify ineligible accounts see a paid offer rather than another trial.
7. On a supported physical iPhone, check Spanish synthesis, slow playback, highlighting, speech recognition, permission denial, interruptions, screen changes, and app backgrounding. Ensure Write works when recognition is unavailable.
8. Check VoiceOver, large Dynamic Type, Reduce Motion, landscape, and iPad layout. Spanish text has a Spanish locale, but correct VoiceOver pronunciation needs device verification.
9. Save and reopen a contribution draft. Submit it locally; verify pending-review status and zero published contributions. Nothing should upload.

## Not production-ready

No production StoreKit product, final price, hosted privacy policy, remote publishing API, real AI editor, native-speaker content review, or brand clearance is configured. The subscription file's $4.99 monthly price is only a local testing placeholder. App icon and final branding are intentionally not finalized.
