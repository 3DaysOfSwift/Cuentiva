# CFA implementation review

Source: the user's local CFA Development skill, its canonical specification,
and reference feature, read before design and implementation.

- Each screen has its own adjacent observable main-actor ViewModel, constructed by the View.
- Shared stateless components receive display data only.
- AppModel is the single live composition root with explicit dependency construction and no screen/navigation state.
- Feature managers own access, classification, validation, progression, completion, and streak rules.
- Storage and audio are replaceable boundaries. Local file operations run in actors.
- Domain values live with their owning feature. No Helpers/Utilities/Services folders.
- Views own presentation only. LessonViewModel owns replaceable recording task lifetime.
- Persistence publishes after atomic disk writes; failures retain prior authoritative state and drafts.
- Reentrant concurrent progress mutations are rejected with a recoverable error rather than dropping updates.
- Speech callbacks identify their active utterance/session so obsolete callbacks cannot publish into a new sentence.
- Independent root loads run concurrently. Initializers start no asynchronous work.
- Calendar/clock are injectable for streak tests.
- Selected visual theme lives in the View layer; a second development palette is defined.
- Core feature tests execute independently of AppModel.shared. Each screen ViewModel has test coverage in the iOS test target (compiled, not runtime-executed in this environment).

CFA is an architecture convention, not a runtime framework dependency. Device UI,
VoiceOver, StoreKit dialogs, and microphone tests remain necessary before release.
