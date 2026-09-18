# App Store Connect setup order

Prepared 18 September 2026. These are entry instructions, not a claim that fields have been saved remotely.

## 1. App information

App record created by Matthew. Verify bundle ID `com.3DaysOfSwiftConcurrency.Cuentiva` and intended team. Use the name, subtitle and keywords in [listing.md](listing.md). Suggested primary category: Education; secondary: Books. Use English as the initial listing language appropriate to the selected locale.

Recommended first public version: 1.0. The project is currently 0.1/build 1; align it with the App Store version before making the release archive. Do not upload a mismatched version.

Copyright must name the actual rights holder, with the year. Keep marketing focused on Cuentiva; do not invent a company to fill legal/account fields. Complete content rights, age rating, export compliance and applicable distribution/account questions accurately. Do not choose a children's age category merely because the artwork is cute: review generated stories and open-ended chat too.

## 2. Pricing and purchases

App download: Free, including the introductory book. Create one auto-renewable subscription group named **Cuentiva Library**, with these two products at the same service level:

| Field | Monthly | Annual |
|---|---|---|
| Product ID | `com.3DaysOfSwiftConcurrency.Cuentiva.monthly` | `com.3DaysOfSwiftConcurrency.Cuentiva.annual` |
| Duration | 1 month | 1 year |
| US price | USD 9.99 | USD 39.99 |
| Billing | Each month | Full amount each year |

These are new subscription products; do not reuse the old non-consumable product ID. Stop offering the lifetime product for sale. Existing verified lifetime ownership is still honoured by the app. Configure localization, availability and review screenshots for both subscriptions. Local StoreKit files do not create live products.

Both subscriptions provide identical library access while active. The annual plan is selected by default, with its full yearly price shown and “Ahorra con el plan anual” when cheaper than twelve monthly payments. StoreKit supplies localized prices. Restore purchases and Manage subscription are available. Cancellation keeps access until expiry; revoked, expired or upgraded transactions do not grant access.

For this initial configuration leave Billing Grace Period disabled: this implementation uses verified transaction expiry and does not extend access for a grace period. Verify renewal, expiry, cancellation, refund, plan changes, restoration and offline access in sandbox/TestFlight before release. Ensure ongoing content/service value for subscribers, and update the published support/privacy/terms pages to match recurring billing.

Chat continues to use earned doubloons and requires supported on-device Apple Intelligence. Neither chat nor doubloons are sold separately.

## 3. Public pages and declarations

Publish [support](support-page.md) and [privacy](privacy-page.md) after replacing their placeholders. Supply the final HTTPS URLs and public support contact; add them in App Store Connect and inside the app. A privacy sentence is not a policy link.

Complete App Privacy from the released implementation and service behavior. Local storage alone does not establish the answer for GitHub delivery, location services or website support forms. The checked-in privacy manifest is not a substitute for the questionnaire. Declare accessibility features only after testing them.

## 4. Product page

Copy [listing.md](listing.md) into the matching fields. Use [screenshots.md](screenshots.md) for the image order. App preview video is optional and deferred for the first release. Avoid unsupported fluency, accuracy, unlimited-content or guaranteed learning claims.

## 5. Review and release

Enter a real review contact privately in App Store Connect. No app sign-in account is required. Copy and verify the review notes from listing.md against the exact uploaded build. Select manual release so approval does not publish immediately. Run [release-checks.md](release-checks.md), upload a validated archive, test it with TestFlight, then attach the build and both subscription products before submission.

## References

- [Apple: first In-App Purchase submission](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)
- [Apple: listing fields](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [Apple: App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
