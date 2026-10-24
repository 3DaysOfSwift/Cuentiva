# Release and maintenance

Status: release candidate, not yet approved for submission. Updated 24 October 2026.

## Scope and accepted product choices

Freeze 1.0 around the existing books, practice, verbs, storyteller chat, Role Play and eReader. Keep the current free-trial button wording and physical-line interleaving in the eReader, as explicitly requested by the product owner. Do not add abandoned Little Tips or human chat. Gifts remain writing after book 1, chat after book 2, verbs after book 3. Purchases restore access; they do not restore locally stored progress or conversations onto another device.

## Completed engineering work

- Chat feature checks verified subscription availability, scenario prerequisites and ended sessions, including after waiting for another reply and after generation. Reset requires fresh payment consent. Tests cover queued completion and denied access.
- Role Play owns its screen model and safely handles missing storytellers. Unlock policy is shared with the chat feature through learner progress.
- Root retains prepared presentation values and welcome data, not other screens' view models. Today and welcome own their screen models. Icon Settings has a separate model from the storyteller reveal.
- Settings explains local transcript storage and the ten-minute paid recovery window.
- CI runs model tests, bundled-content checks, iOS tests and a Release simulator build. This workflow has not yet run on GitHub; its first green run is required evidence.

## Verification on 24 October 2026

- Executed model suite: **186 tests across 37 suites passed**, including SwiftData persistence tests and chat access/queue regression tests.
- All application Swift source compiled into an iOS simulator module with testing enabled.
- All iOS test source passed a compiler type check against that module. These iOS tests were **not executed** here.
- Library binary check passed (52 books); publisher alignment passed (52 books, nine storytellers); project/privacy plist lint and whitespace checks passed.
- Full Release simulator build attempted but failed at LaunchScreen storyboard compilation because CoreSimulator was unavailable to the runner. No signed archive or TestFlight/device validation was completed.
- Test runner required a fresh build directory after the repository was moved; stale caches from the old path failed to load SwiftShims. A clean build resolved that tooling failure.
- Initial executed suite exposed obsolete five-/eleven-book gift assertions and a chat test that expected sending after completion. Tests now reflect the already-shipped-in-source one-/two-book gift rules and the requested ended-session behaviour. No runtime crash was observed in the successful run.

## Release gates still requiring evidence

Record date, device/build, outcome and person responsible for each gate. Do not replace a failed gate with a source type check.

- [ ] Successful clean signed Release archive in Xcode 26.2 or later.
- [ ] Full iOS test suite passes on a supported runtime, with the result bundle retained.
- [ ] TestFlight checks on physical iPhone and iPad (both are currently supported): fresh install, upgrade preserving existing data, offline reading, background/termination recovery, accessibility text sizes, VoiceOver, eReader and navigation.
- [ ] Apple Intelligence on supported hardware: natural Spanish replies, Role Play objectives, no premature completion, one-at-a-time incoming messages, cancellation and errors. Unsupported/unavailable models must show useful explanations without taking coins.
- [ ] TestFlight StoreKit: production product identifiers, localized prices, trial offer configuration, purchase cancellation, restore, expiry/revocation, unavailable StoreKit and no duplicate coin deductions. Local StoreKit fixtures do not prove production configuration.
- [ ] Gifts and daily routines: books 1/2/3, daily rollover, streak revival, exactly-once rewards, practice completion and restored sessions.
- [ ] Fluent Spanish editorial sign-off. Bundled content still states review pending. Audit all 52 books and verb tables for grammar, accents, translations, regional usage, tense explanations, accepted answers and sensible difficulty. Automated completeness tests do not provide editorial certification.
- [ ] Rights and brand review for name, artwork, stories and third-party material.
- [ ] App Store Connect account holder verifies active paid agreement, required tax and banking details, subscription group/products and introductory offers.
- [ ] Complete accurate age rating, export-compliance answers, App Privacy answers, screenshots for supported devices, description, release version/build, reachable Support URL and Privacy Policy URL.
- [ ] Review notes explain the introductory book, subscription, gifts after books 1/2/3, earned doubloons and supported-device requirements for on-device AI. Supply any access instructions Apple needs to review the complete product.
- [ ] Validate live catalogue publishing and next-launch activation using the procedure below.
- [ ] Push reviewed commits, obtain green CI, tag the exact archive source and record the App Store build number. Do not tag a release before the archive is verified.

## Content publishing rehearsal

The publisher is the separate GlobalEnglish-SpanishLearningBooksCollection repository. An ordinary Git commit does not update installed apps.

1. Run the publisher's tests and deterministic builder. Run `python3 scripts/sync_publishing_library.py --check` in Cuentiva with the sibling publishing checkout present.
2. Review stable book IDs, revisions, translations, pack sizes and checksums. Never reuse an existing immutable release asset for different bytes.
3. Run the publisher's manual release workflow after editorial approval. Confirm the public `releases/latest/download/catalogue.json` and every referenced pack are accessible and checksums match.
4. On TestFlight, use Settings' explicit update check, close and relaunch, and verify new content appears while old completions remain. Automatic checks occur once per local calendar day.
5. Exercise offline, missing pack and checksum failure cases in a controlled test environment. The previously verified library must remain available.
6. Rehearse recovery with a new, valid release containing corrected content. Do not delete or overwrite assets referenced by existing catalogues. Keep a record of the last verified release.

No production publication was performed during this hardening task. Web retrieval of the current manifest and privacy page was unavailable in this environment; that is not proof either URL is broken.

## Maintenance routine

For each release: run CI, review changes and migrations, exercise purchases and representative learning journeys in TestFlight, archive the result bundle and tag the source used for the signed build.

Weekly after launch: inspect App Store Connect crash reports and customer feedback, triage data-loss/purchase issues first, check support and privacy links, and record reproducible issues with device/OS/build. Never request private learner conversations unless necessary and explicitly volunteered.

For each content update: editorial review, publisher validation, live download check, stable-ID verification and a recorded rollback/recovery option.

Before each major iOS release: run the supported-device matrix, StoreKit, speech, on-device AI, background recovery and accessibility checks. Keep dependency/toolchain changes separate from product changes where practical.

Keep ownership simple: the maintainer owns release evidence and support; the account holder owns contracts, tax/banking and App Store submission; a fluent editor owns language approval. Source availability is not evidence that the app is already published.
