# App Store Connect setup order

Prepared 18 September 2026. These are entry instructions, not a claim that fields have been saved remotely.

## 1. App information

App record created by Matthew. Verify bundle ID `com.3DaysOfSwiftConcurrency.Cuentiva` and intended team. Use the name, subtitle and keywords in [listing.md](listing.md). Suggested primary category: Education; secondary: Books. Use English as the initial listing language appropriate to the selected locale.

Recommended first public version: 1.0. The project is currently 0.1/build 1; align it with the App Store version before making the release archive. Do not upload a mismatched version.

Copyright must name the actual rights holder, with the year. Keep marketing focused on Cuentiva; do not invent a company to fill legal/account fields. Complete content rights, age rating, export compliance and applicable distribution/account questions accurately. Do not choose a children's age category merely because the artwork is cute: review generated stories and open-ended chat too.

## 2. Pricing and purchases

Recommended app download price: Free, with the existing introductory book and two separate non-consumable unlocks. Confirm storefront availability intentionally. Complete the Paid Apps Agreement, tax and banking setup before paid-product testing.

| Field | Library | Chat |
|---|---|---|
| Reference name | Cuentiva Library Unlock | Cuentiva Storyteller Chat |
| Type | Non-Consumable | Non-Consumable |
| Product ID | `com.3DaysOfSwiftConcurrency.Cuentiva.lifetime` | `com.3DaysOfSwiftConcurrency.Cuentiva.storytellerChat` |
| Display name | Cuentiva Library | Storyteller Chat |
| Description | Unlock the story library with one purchase. | Practise Spanish with storytellers. Requires Apple Intelligence. |
| Intended base price | US storefront: USD 14.99 | UK storefront: GBP 24.99 |

Select the intended base country/currency and inspect Apple's resulting other-storefront prices. Do not set every region to the same numeric price. These prices come from the product decisions; they have not been verified live. Use exact product IDs above; local StoreKit files do not create products.

Library review note: Unlocks the wider reading collection after the introductory book. Restore is available in Settings and the library paywall. No subscription.

Chat review note: Separate unlock for on-device Spanish conversations. Requires Apple Intelligence availability on a supported device. Reach it through a storyteller biography or Settings. It does not purchase the library unlock. Confirm the navigation and availability gating in the submitted build.

Capture each actual purchase screen for its own review screenshot. These are separate from marketing screenshots. Submit the initial products with the app version and verify neither is left at Missing Metadata.

## 3. Public pages and declarations

Publish [support](support-page.md) and [privacy](privacy-page.md) after replacing their placeholders. Supply the final HTTPS URLs and public support contact; add them in App Store Connect and inside the app. A privacy sentence is not a policy link.

Complete App Privacy from the released implementation and service behavior. Local storage alone does not establish the answer for GitHub delivery, location services or website support forms. The checked-in privacy manifest is not a substitute for the questionnaire. Declare accessibility features only after testing them.

## 4. Product page

Copy [listing.md](listing.md) into the matching fields. Use [screenshots.md](screenshots.md) for the image order. App preview video is optional and deferred for the first release. Avoid unsupported fluency, accuracy, unlimited-content or guaranteed learning claims.

## 5. Review and release

Enter a real review contact privately in App Store Connect. No app sign-in account is required. Copy and verify the review notes from listing.md against the exact uploaded build. Select manual release so approval does not publish immediately. Run [release-checks.md](release-checks.md), upload a validated archive, test it with TestFlight, then attach the build and both initial IAPs before submission.

## References

- [Apple: first In-App Purchase submission](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)
- [Apple: listing fields](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [Apple: App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
