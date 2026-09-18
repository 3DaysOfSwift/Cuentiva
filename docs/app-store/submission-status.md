# Submission preparation status — 18 September 2026

## Completed this pass

- Recorded Matthew's confirmation that the App Store Connect app record exists.
- Prepared App Store Connect entry order, exact IAP identifiers/localizations, intended prices, and review instructions.
- Added suggested keywords and categories to the listing. Checked field lengths: name 8/30, subtitle 23/30, keywords 89/100 bytes, promotional text 121/170, description 1025/4000.
- Prepared six-image screenshot direction using genuine UI and existing artwork, with separate iPhone/iPad capture requirements.
- Created an iterative release candidate checklist.
- Ran scripts/verify.sh: 81 core tests in 19 suites passed; project and privacy manifest plist validation passed; diff whitespace check passed. Log: /tmp/cuentiva-submission-check.log.
- Inspected current project settings: app bundle ID com.3DaysOfSwiftConcurrency.Cuentiva; team LW4V9MRNCX; version 0.1/build 1; iPhone and iPad enabled.

## Pending

- Public Wix support/privacy URLs and support contact; add genuine links in the app and App Store Connect. Current library paywall has privacy text rather than a policy link.
- Live product configuration and account agreements have not been inspected or changed.
- Version 1.0 is recommended for first release but not applied; confirm it matches the App Store record before archive.
- Fresh screenshot captures and composed exports have not been produced. Existing screenshots are visual references from older iterations.
- No iOS build, archive, simulator UI run or physical-device test was performed in this documentation pass. Previous iOS validation encountered unavailable platform/simulator services; recheck the environment in the next code-validation pass.
- No release-readiness claim: core tests exclude UI, audio, device AI and real StoreKit flows. Run the release checklist before submission.

No remote metadata, purchases or release settings were changed. No upload, commit or push was performed.
