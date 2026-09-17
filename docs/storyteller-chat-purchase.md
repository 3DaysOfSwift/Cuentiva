# Storyteller Chat

Storyteller Chat is a separate non-consumable purchase, intended to cost £24.99
in the UK. The library lifetime purchase remains separate. No coins are charged
per message, and there is no subscription.

## Using it

Open Settings → Storyteller Chat, or a storyteller’s bio → Talk with their name.
Before purchase, the screen checks that Apple Intelligence is available with
Spanish and English support. Unsupported devices can restore an existing purchase,
but are not offered a buy button. The price comes from StoreKit’s localized offer.
A verified purchase immediately opens the conversation screen.

Choose A1–C2 and type in Spanish or English. Each reply offers an English
translation, read-aloud, and a suggested response; corrections appear when useful.
Tap the new-chat button to delete that character’s conversation and start again.
Conversations with different storytellers are separate. Stop or leave the screen
to cancel an unfinished reply.

The full transcript is saved atomically in `chat.json` in Application Support.
No chat content is uploaded. The model receives a rolling summary plus the last
two exchanges in a fresh session, keeping requests bounded as conversations grow.
Messages are limited to 500 characters. Long-term memory is approximate: the
summary may lose detail, and AI answers and corrections can be wrong.

Chat is composed at launch but does not check purchases, load transcripts, or
start AI inference until its screen opens. Generation checks the chat entitlement
before and after inference. Cancellation and failed generation/save retain the
composer draft and do not append a partial exchange.

## Local testing

Select the shared **Cuentiva Chat UK** scheme in Xcode. Its StoreKit configuration
is `Cuentiva/3 - App Resources/StorytellerChat.storekit`, with a UK storefront and
£24.99 chat test price. Both library and chat products are present. The ordinary
Cuentiva scheme retains its original test configuration/storefront and does not
contain the chat test product. Local StoreKit purchases take no real payment.

Use a real Apple Intelligence compatible device with the model ready to test real
conversation generation. The simulator may correctly report AI unavailable; do
not bypass that check to offer customers a purchase on unsupported hardware.

Check these paths before release:

- Existing library owner is still asked to purchase chat separately.
- Cancelled or pending purchase does not unlock chat; verified success does.
- Restore with a fresh install/manager unlocks chat without another purchase.
- Refunding/revoking chat removes access while keeping the library entitlement.
- Disable Apple Intelligence: no buy button or generation, with a useful explanation.
- Generate, translate and listen on a compatible device; background/cancel a reply.
- Relaunch and reopen the conversation, then delete only that character’s history.

Automated core tests cover gating, availability, bounded context, persistence,
failed writes, cancellation, revocation and overlapping requests. StoreKit tests
cover the separate product and restoration. Simulator execution is still required
in Xcode; the agent environment could not access CoreSimulator.

## Production activation

Product ID: `com.3DaysOfSwiftConcurrency.Cuentiva.storytellerChat`
Type: **Non-consumable**
Display name: **Storyteller Chat**
Suggested description: **Practise Spanish with AI storytellers on your device.**

Create that product in App Store Connect, select the UK base region and £24.99,
check regional prices, and add localization and review screenshots. Submit the
working app and IAP for review. The app reads the real localized price from
StoreKit in production. The local configuration does not create a live product.
Disclose Apple Intelligence compatibility in product and app descriptions.

This implementation has not been published to the App Store. Real-device AI
quality, purchase/restore and UI checks are required before public release.

## Implementation review

Setup calls now await one shared operation. Refreshing preserves loaded chat,
and loading errors are separate from purchase feedback. Purchase eligibility is
checked inside the feature manager; screens receive a narrow chat API instead
of direct access to its purchase manager. Restore does not depend on AI or
local history loading successfully. Models, persistence, paywall and composer
are separated into named files. Long transcripts render lazily.

Validation: 66 core tests passed after refinement. Added presentation regression
tests for cancelled purchase and preserving purchase feedback after refresh;
these still require Xcode execution. Swift syntax and project structure checks
passed. The simulator destination remained unavailable to the agent environment.
