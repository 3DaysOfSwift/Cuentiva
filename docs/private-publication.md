# Personal bookshelf

Write creates private drafts. After reviewing a saved tale, tap **Publish to my
library**. The story appears in Discover with the reader’s generated storyteller
name, biography and chosen creature artwork. New onboarding draws are 80% fox,
10% turtle and 10% unicorn; existing profiles keep their creature.

The current weekly rule is **one user-selected publication every seven days**.
It is not scheduled generation. The next eligible date is shown in Write. Drafts
can still be generated while waiting. Publishing the same story again returns its
existing book without consuming another allowance. The rule uses the device’s
local date/calendar and survives relaunches; reinstalling without restoring local
data removes the private archive, just like other on-device content.

Publication is one atomic write to the fantasy archive. It stores a stable book
ID, sentence IDs, the publication date and a snapshot of the book. The library
combines these personal books with the downloaded catalogue at read time. Server
pack replacement cannot remove them and never uploads them. Current storyteller
profile details are used when displaying the personal author. Older archives
without a publications field remain readable.

Unfinished personal books receive priority in Discover’s normal library ordering.
Today’s existing three recommendations stay stable for that day. Personal books
use the normal reader, completion and progress features and the existing library
purchase gate. Generated tales currently target A2; their vocabulary entries use
surface words rather than pretending an AI-generated grammatical analysis exists.

Validation: 71 core tests passed, including deterministic 80/10/10 draw weights,
weekly and duplicate guards, failed-write recovery, legacy decoding, catalogue
replacement, personal author lookup and normal reading/completion. Swift syntax
passed. Real iPhone UI verification remains outstanding because the simulator
is unavailable to the agent environment.
