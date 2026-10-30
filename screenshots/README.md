# App Store screenshot draft — 24 October 2026

Six genuine captures are in `source/iphone/`. Open `index.html` to review the set. Individual presentation layouts are in `presentation/`.

The source PNGs are 1260 × 2736, suitable for Apple’s 6.9-inch iPhone screenshot size group. They are not 6.5-inch exports. The presentation HTML targets 1242 × 2688 for the planned 6.5-inch set, but has not yet been rendered and visually verified; do not upload it as a final asset.

The running Simulator build was captured without resetting data or fabricating conversations, completion, or purchase success. English visibility was restored after capture. Opening sentence practice may leave an unfinished practice session.

## Before upload

- Recapture against the final signed release candidate, whose installed build identity is verified.
- Render and inspect the 6.5-inch presentation exports, or explicitly choose the supported 6.9-inch source set.
- Capture and review the real iPad layout separately (the project supports iPad).
- Confirm the listing locale, screenshot order and claims. The AI screen caption includes the supported-device requirement and doubloon cost.

## Purchase and submission checks

Source review found production product IDs `com.cuentiva.monthly` and `com.cuentiva.annual`, verified transaction handling, entitlement updates and Restore Purchases. This does not establish that App Store Connect products are fully configured.

App Store Connect displayed an updated Developer Program License Agreement requiring the Account Holder’s acceptance, then the session expired before subscription records could be inspected. Reauthenticate, resolve the agreement, and verify subscription pricing, introductory offer, group, availability and review metadata.

Upload a signed build to TestFlight, then verify product loading, sandbox purchase, relaunch and restore on a real device. The repository currently declares marketing version 0.1/build 1 while App Store Connect showed version 1.0; align release version/build before archive. First subscriptions must accompany the app version submitted for review. No build, screenshot or review submission was uploaded during this task.
