# Phone experience polish — 19 September 2026

## Reading journey

- Onboarding keeps its Read button in a bottom safe-area inset and shows the same bilingual title, storyteller link, reading length and description as Books.
- Discover is now labelled Books. Below the carousel, the selected book shows its English title, description, level and sentence count, then its reading action. The hidden stats inset increased from 80 to 90 points.
- The sentence lesson ends with “First chapter completed”, then a dedicated celebration. “Read more fluently” opens the full reader, with Chapter 1 and Chapter 2 headings. Books without a continuation only show Chapter 1. No completion reward is issued by the chapter celebration.
- Book completion keeps “Your next chapter” anchored at the bottom. Writing and theme milestones retain their destinations. Storyteller details link to the biography.
- All 52 source summaries were rewritten from the existing story text. Both bundled JSON/DAT resources and the adjacent content repository now contain the expanded descriptions.

## One-week subscription trials

The local `Cuentiva.storekit` configuration includes a one-week, zero-price introductory offer for **both** monthly and annual products. The paywall displays trial copy only when the returned offer is a one-week free trial and StoreKit confirms eligibility. Prices come from the selected StoreKit product; neither eligibility nor payment success is fabricated. Entitlement checks still finish independently of price/trial lookups.

**Production action required:** In App Store Connect, open each subscription in the Cuentiva Library group and add an introductory offer: **Free trial → 1 week**, with the intended countries and dates. Configure both monthly and annual products. Local StoreKit configuration does not configure the live store.

Apple permits one introductory offer per subscription group, not a new free trial every time someone changes plans. See [Apple’s introductory-offer guide](https://developer.apple.com/documentation/storekit/implementing-introductory-offers-in-your-app) and [App Store Connect offer setup](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions/).

The app’s paywall displays Pipa with rounded corners and removes “Not now”. The native Apple purchase-confirmation sheet is controlled by StoreKit; the app cannot override its icon mask or layout.

## Artwork

- App icon: existing `StorytellerPipa.imageset/portrait.jpg`, exported as an opaque 1024×1024 PNG to `AppIcon.appiconset/AppIcon.png`. The source illustration is 512×512; the export preserves that artwork rather than inventing extra detail. Pipa also appears on the paywall and tomorrow footer. Existing users retain their personal storyteller identity.
- Zumi: new built-in image-generation output installed as `StorytellerZumi.imageset/portrait.png`; the previous asset had no image file. Inspected the generated illustration before installing it.

Generation prompt:

> Create one square app storyteller portrait for Zumi, a tiny cute anthropomorphic fly with enormous curiosity, holding a little open book, small explorer satchel, friendly intelligent huge eyes, translucent delicate wings. Hand-painted watercolor children's storybook illustration on warm pale cream paper, muted teal, moss, ochre and rust palette. Charming, adventurous and slightly mysterious, friendly rather than realistic insect. Single character centered chest-up, silhouette readable inside circular avatar crop. No lettering or border. Match the supplied reference's watercolor rendering and cream background; reference is Pipa the lizard, do not copy its species. This output replaces a missing portrait in the Cuentiva iOS app.

## Device checks

1. Fresh install: Read remains bottom-anchored with large text; avatar opens the biography.
2. Finish Chapter 1: celebration appears without granting a doubloon or completing the book; continue to both chapter headings and finish the whole book.
3. Paywall: both fresh-account plans offer a week; a previously eligible/used account must not be promised another trial. Confirm actual terms in Apple’s purchase sheet.
4. Books: selected details precede the button; Pipa’s fixed profile link and the three-format showcase are readable; hidden stats fully disappear at rest.
5. Ordinary and milestone completions: bottom button remains reachable and gifts still open correctly.

Existing downloaded snapshots remain authoritative. The adjacent content release has been built locally but not published; those installs receive the new descriptions after that content release is published, downloaded and activated on the following launch. Fresh installs use the rebuilt bundled data immediately. No saved personal stories or progress were rewritten.

## Character roles

Pipa is the welcoming guide and app mascot. Onboarding introduces Pipa before Brasa’s first story, El café de Ana. Brasa remains the first book’s author. The fox remains the lead image for the personal-writing invitation; the existing 80% fox character draw and saved identities are preserved.

## Books layout refinement — 19 September 2026

- Larger Your next book heading; selected details show English title, summary, level/length, then the reading button.
- Meet the storytellers has a fixed top-right Pipa bio link and the subtitle Helping bring Spanish to life through our storytelling.
- Three ways into Spanish showcases Scripts, Verb training and Stories, followed by A1 – B1 Book Library.
- Nearby, its location provider and permission declarations were removed. All 52 bundled stories remain available through Books; legacy metadata stays readable.
- Validation: 124 model tests in 33 suites passed; all iOS app and test sources passed Swift 6 simulator-SDK typechecking. Project syntax and diff whitespace checks passed. Simulator runtime/UI validation remains unavailable in this session.

## Personal icon and Pipa welcome — 19 September 2026

Pipa welcomes new readers with a larger portrait and explains meeting unfamiliar words through stories, listening and speaking, then using them to talk about their own lives. The bottom first-story action names the book’s storyteller dynamically.

After a creature reveal, readers may explicitly choose its bundled app icon. Fox, turtle and unicorn are supported. Pipa remains the default and can be restored from the storyteller profile. No icon changes automatically; unsupported devices omit the invitation, and failed changes show a retry message. This is independent of on-device AI availability.

Alternate icon sets are registered in both build configurations using Apple’s asset-catalog build setting. Reference: https://developer.apple.com/documentation/xcode/configuring-your-app-to-use-alternate-app-icons

Validation: 124 model tests passed. Swift 6 simulator-SDK typechecking passed for all app/test sources, including new reveal-view-model tests for opt-in, repeat selection, restoring Pipa, unsupported devices and failure/retry. All three alternate icon files are opaque 1024×1024 PNGs. Project syntax and diff checks passed. The new iOS tests were not runtime-executed; actual Home Screen switching and compiled asset-catalog packaging still need verification on a working simulator/device.

## Pipa tells the first story — 19 September 2026

Ana’s little café (`cafe`) is now credited to Pipa (`marta`, the existing stable author ID). Ana remains the character in the story. Both bundled DAT files and the content repository source were regenerated so the onboarding cover, profile and button agree with Pipa’s welcome. The book ID, sentences and completion history are unchanged. Content packs were built locally, not published.

Future editorial direction: Brasa can introduce scripts and the unicorn can introduce verb books. Their timing is intentionally undecided; no new gates or scheduled introductions were added.

Validation: 124 model tests and three content-pack tests passed. The bundled-content test now verifies that the introductory book resolves to Pipa. DAT freshness checks passed.

## Introductory book on Pipa’s profile — 19 September 2026

Author queries now include the already-loaded free introduction when paid access is unavailable. The author and other query filters still apply; general library searches and daily recommendations remain locked. Loading the introduction invalidates previously empty profile results. No paid catalogue loading is triggered.

Validation: 125 model tests passed, including querying Pipa before/after introduction loading, excluding another author, and retaining paid-library gates.
