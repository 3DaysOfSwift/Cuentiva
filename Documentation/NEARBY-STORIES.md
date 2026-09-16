# Nearby Stories

A separate paid-library tab discovers location-tagged books within 5, 25 or 100 km of a fresh, one-shot device location. It sorts by distance. Discover continues to show the general library; location-tagged books join it and Completed after completion, so readers retain their travel souvenirs. No background tracking is requested. Browsing coordinates are memory-only and discarded on backgrounding. Refresh explicitly after moving; a fix older than five minutes is no longer used for new results.

Contribute offers “Leave this story here”. “Leave a story here” from Nearby preselects it. Submission requests When In Use access, resolves a locality using iOS 26 MapKit, then asks for confirmation. Coordinates, horizontal accuracy, timestamp and approximate place name are saved with the submission. GPS is an estimate, not proof of exact presence. Fixes older than five minutes or less accurate than 5 km cannot be submitted. Denied permission or lookup failure leaves general discovery and unlocated contributions available.

The feature manager rejects changes/removal of an existing submission location, including after restart, by comparing the saved repository record. Text edits preserve the location. Users can explicitly delete their local story and location with confirmation. This is a deletion, not a way to move a published pin.

The current demo has no publishing server and no location-tagged seed books. It does not relabel fictional samples as real community submissions or insert local drafts into the published library. Pending submissions stay local. Tests supply synthetic coordinates to exercise populated results without claiming real authorship.

## Server integration

BookRepository remains the catalog boundary; NearbyFeature is the replaceable discovery boundary. A production service must query nearby books on the server, keep precise submission coordinates private, return approximate locality labels, persist immutable submission metadata, and validate authorization, moderation and timestamp rules. Do not ship the entire worldwide location catalog to clients as a real geographic access control. GPS spoofing is not prevented by this demo. Retain completed-book access when readers travel, and provide a server-backed withdrawal/deletion process.

Before enabling uploads, update privacy disclosures for location collection and retention. Today the app itself has no contribution upload service. Apple's location/geocoding service is used to identify places; location is not used for ads or tracking. The content's subject may differ from its submission location: a Mexico story submitted in Bali belongs to Bali.
