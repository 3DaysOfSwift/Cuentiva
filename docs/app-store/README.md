# First App Store submission

Status: Matthew confirmed that the Cuentiva App Store Connect record is created. Submission preparation is in progress. Product setup, screenshots, archive and submission are not yet verified. Wix support/privacy URLs are pending.

## Existing project configuration

- Bundle ID: `com.3DaysOfSwiftConcurrency.Cuentiva`
- Team: `LW4V9MRNCX` (confirm this is the intended App Store account)
- Version/build: `0.1` / `1` (choose the initial public version before archiving)
- Deployment target: iOS 26.0
- Device families: iPhone and iPad; both need layout and screenshot verification
- Archive configuration: Release; local StoreKit fixtures belong to debug launch actions
- Library subscriptions: `com.3DaysOfSwiftConcurrency.Cuentiva.monthly` ($9.99/month) and `com.3DaysOfSwiftConcurrency.Cuentiva.annual` ($39.99/year), in one subscription group.
- Chat: one earned doubloon per session; no chat product or coin purchase.

StoreKit configuration files do not create live products. Configure prices and availability in App Store Connect and verify the localized prices in TestFlight. Only the library purchase is offered. Chat uses coins earned through book completion. No coin purchase is implemented.

## Submission blockers

- [x] Create the app record (confirmed by Matthew). Before upload, verify it uses `com.3DaysOfSwiftConcurrency.Cuentiva`.
- [ ] Publish support and privacy pages using the draft copy here; provide real contact details and final URLs.
- [ ] Add the final privacy/support links inside the app. The current paywall's privacy sentence is not a privacy-policy link.
- [ ] Configure both library subscriptions, agreements/tax/banking where required, localization and review screenshots.
- [ ] Build and validate an archive with the intended team. Current automated iOS validation is blocked by unavailable local platform/simulator services.
- [ ] Verify migrations, cold/warm launch and sentence navigation on a physical device, including a normal launch outside Xcode.
- [ ] Test fresh purchase, restore, cancelled purchase, offline owner access and earned-coin chat sessions in TestFlight/sandbox.
- [ ] Test AI-supported and unsupported devices; unavailable AI must not be sold as usable. Confirm chat availability and coin charging on hardware.
- [ ] Review all bundled stories, generated-content behavior and artwork rights; answer the age-rating questionnaire from the actual content/capabilities.
- [ ] Complete App Privacy after reviewing app, GitHub delivery, Apple purchase services and any support-site data handling. Do not copy a blanket “no network data” claim.
- [ ] Capture current iPhone and iPad screenshots, finalize metadata and accessibility declarations based on testing.
- [ ] Attach first IAPs to the initial app-version submission, add review notes and select a release option.

## Prepared material

- [App Store Connect setup order](connect-setup.md)
- [Screenshot art direction and capture list](screenshots.md)
- [Release candidate test plan](release-checks.md)
- [Listing and review notes](listing.md)
- [Wix support page draft](support-page.md)
- [Wix privacy page draft](privacy-page.md)

Use Xcode: select Cuentiva, select a generic iOS device, Product → Archive, then Validate App in Organizer. Upload only after validation and the product setup above. A successful core test suite is not an App Store readiness certificate.

Apple references, checked 18 September 2026:
- [Submitting an app](https://developer.apple.com/app-store/submitting/)
- [App Review information and support/privacy links](https://developer.apple.com/app-store/review/)
- [Submitting the first In-App Purchase](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)
- [App privacy details](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
