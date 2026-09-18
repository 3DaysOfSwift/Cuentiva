# Storyteller Chat: earned doubloons

There is no separate chat purchase or coin-purchase option in the app.
Complete a previously unread story or script to earn one doubloon, once per book.
Matching practice and rereading do not mint more coins. Existing balances remain;
historical completions are not backfilled.

Open a storyteller bio or Settings → Storyteller Chat. One doubloon pays for
one continuous topic session. The first valid AI reply spends the coin; further
messages cost nothing. AI failure, cancellation before payment, or a failed
wallet save does not debit the balance. Wallet saves are atomic.

Leaving the screen or backgrounding the app ends the session and clears its
in-memory transcript. Starting a new topic also ends the paid session. Returning
requires another coin. Brief inactive states cancel pending inference without
ending an already paid session. No per-message or elapsed-time fee applies.

Generation requires Apple Intelligence on a supported device. The model receives
a bounded summary and recent exchanges, so very long sessions may lose details.
No chat is uploaded. Legacy transcript storage remains compatible but is no longer
read or written by this feature. There is no separate chat StoreKit product or test scheme.

Verify on a physical device: earn a coin, open chat, send multiple messages,
leave and reopen, try with no coins, interrupt inference, and background the app.
Core tests exercise balances, duplicate completions, failed saves, invalid replies,
cancellation, session closure, and bounded context using a fake generator.
