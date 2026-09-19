# Release candidate checks

Do not mark a check complete without results from the exact candidate. App Store Connect preparation can proceed while these remain open.

## Iteration 1: release wiring

- [ ] Add real support/privacy links to Settings and purchase flows once URLs arrive.
- [ ] Confirm version, build, team, product IDs and live IAP metadata.
- [ ] Build Release for device, validate archive; inspect warnings and bundled resources.
- [ ] Confirm debug StoreKit configuration and demo notices cannot affect distribution.
- [ ] Verify app icon in archive and all intended device families.

## Iteration 2: correctness and performance

- [ ] Run core suite and iOS ViewModel/UI tests; retain logs and exact revision.
- [ ] First install: offline seed loads; no download required to display introductory content.
- [ ] Existing install: all saved progress, private stories and chats survive SwiftData migration. Remove legacy files only after successful import; exercise failed save/retry.
- [ ] Measure cold launch, warm launch and Next sentence outside the debugger on physical hardware. Record timings by stage, not only total workflow time. Test with normal and expanded user data.
- [ ] Background sync never changes the visible session or blocks local reading. Next launch adopts downloaded data safely.
- [ ] Complete a book twice: no duplicate completion/reward. Day change, time-zone change and weekly story allowance behave predictably.
- [ ] Test purchase, pending/cancelled purchase, restore, refund/revocation, unavailable store and offline ownership. Library and chat remain separate.
- [ ] AI available/unavailable/disabled cases: onboarding remains usable, profile saving works, paid chat cannot be bought when unusable, failed or cancelled generation never fabricates success.

## Iteration 3: presentation and submission

- [ ] iPhone and iPad layouts, keyboard, long titles, all themes, large text, VoiceOver and Reduce Motion.
- [ ] Microphone denied: clear fallback. No unnecessary permission prompt at launch.
- [ ] Review bundled stories and artwork rights; inspect AI behavior against advertised use.
- [ ] Screenshots match final UI and state purchase/device requirements.
- [ ] Privacy, age rating, accessibility and export declarations reviewed against actual build.
- [ ] TestFlight purchase and offline reading smoke test on the uploaded build.
- [ ] Review contact, review notes, initial products, selected build and manual release checked before submission.

## Evidence for this preparation pass

See `submission-status.md` for current results and limitations. Core tests do not cover SwiftUI layout, audio, Apple Intelligence generation or real App Store transactions.
