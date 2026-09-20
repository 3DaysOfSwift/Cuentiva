# Library editorial edition 4

All 52 existing book slots have been rewritten: 46 stories, three scripts and three verb stories. Each has three chapters with a setup, complication and resolution. The collection contains 792 bilingual passages across 156 chapters.

## What changed

The previous collection included generic human characters, instructional summaries and a large block of books credited to Nube without a distinctive cloud narrator. This edition gives every book a specific incident, a character with something at stake, an escalating problem and an ending that changes the situation. Stories vary between mystery, comedy, travel, quiet friendship and unsettling magic. They do not all conclude with an explicit lesson.

The first 25 manuscripts use the storyteller's first-person voice. Later books use third-person narration or scripts; attribution identifies the storyteller, not necessarily every protagonist. Foxy is a curious guest fox in two stories, not a newly unlocked app profile or the user's chosen name.

## Character continuity

- **Pipa:** lizard, clothing designer, notebook, travel, language exchange, homesickness and departures. His introductory Americas route and WhatsApp exchanges remain central.
- **Brasa:** generous small dragon; food, accidental overheating, hospitality and theatre improvisation.
- **Musgo:** woodland wizard; roots, inherited magic and forbidden spells whose costs affect memories and neighbours.
- **Zumi:** a tiny **fly**, as specified by the current bio; practical experiments, awkward scale, rain-soaked wings and redesigns after failure.
- **Luma:** moth; small lights, nocturnal kindness and courage rather than simply chasing brightness.
- **Nube:** wandering cloud; wind, rain, weight, maps, departures and changing perspective.
- **Tilo:** patient tortoise, listener and theatrical organiser; trust, testimony and making room for other voices.
- **Mora:** mushroom sprite, as specified by the current bio; letters, riddles, words, bargains and social misunderstandings. She has not silently become a unicorn.
- **Faro:** owl; night vision, late dinners, farm stories, forest rumours and his mouse lookout Benji. The three Thailand stories form a connected fictional travel sequence.

## Learning and reader behaviour

Existing A1/A2/B1 labels and book IDs are retained. A1 uses mainly present-tense, short clauses; A2 introduces narrative past tenses; B1 allows uncertainty, competing accounts and more complex clauses. These are editorial targets, not independently certified CEFR assessments. Native-speaker editorial review remains pending in the content metadata.

Each verb book contains all six present-indicative forms in **each** of its three chapters. Scripts carry named speakers and narrator/stage directions. Spanish passages have complete English translations.

`sentences` is chapter one, `continuation` chapter two, and `ending` chapter three. The reading flow presents Chapter 1 sentence by sentence, Chapter 2 alone with the flowing reading guide, then Chapter 3 sentence by sentence. Completion requires all three chapters. An optional unaided reread starts with the cover, includes every chapter, hides English until tapped and ends with storyteller credits. `Book.fullText` and `Book.completeText` both include all three chapters.

All 52 books have at least 30 pairs (the smallest has 71). The complete library contains 5,771 pairs across 2,072 distinct surface forms. Today offers three untimed 30-pair games after the three selected books are completed. Each completed game earns one additional doubloon, persisted once per book per day (three daily rewards). A dedicated reward screen shows the saved balance increase. Replays do not duplicate rewards. Legacy days whose group reward was already collected remain paid. The full-deck and timed practice options remain under Completed → Book activities.

Vocabulary counts are rebuilt from the text. `lemmas.json` preserves the existing curated mappings, with literal surface-word fallback for unmapped forms; it is not a complete morphological dictionary. Every book now has a complete English matching glossary for its playable vocabulary, including all scripts and verb stories. `word-meanings.json` supplies surface-form meanings; `glossaries.json` supplies story-specific overrides for ambiguous words. Rebuilding fails if any required meaning is missing or blank. Location-demo metadata is removed; the travel fiction is not represented as a real user submission.

## Updates and saved progress

Book IDs remain stable, preserving completed-book history and rewards. Rewritten passages receive revision-specific IDs so old answers cannot count as reading new prose. A reader with attempts from the old edition resumes the rewrite at its beginning; current-edition attempts resume normally. Saved practice history is retained. Revision 4 extends matching and vocabulary counts to all three chapters while retaining revision-2 passage IDs. Existing chapter-one attempts remain valid and saved completion/reward history is preserved. Older cached revisions are superseded by the bundled matching data.

DAT version 2 adds ending/revision fields; the runtime still reads version 1. A newer bundled editorial revision supersedes older cached text without a launch-time database migration or write. Remote-only books and higher remote revisions remain available. The sibling publishing repository is now aligned with this edition, including all three chapters, matching data and current storyteller profiles. Its four release packs have been built and checked locally. No GitHub release has been published by this alignment step.

## Editing and rebuilding

Authoritative text: [`stories.txt`](stories.txt). Every header is `@id|Storyteller|Spanish title|English title|English summary`. Separate chapters with `---` and bilingual passages with ` | `. Script lines start with `[Speaker]`.

```sh
python3 scripts/rebuild_editorial_library.py
python3 scripts/build_library_dat.py
python3 scripts/rebuild_editorial_library.py --check
python3 scripts/build_library_dat.py --check
python3 scripts/sync_publishing_library.py
python3 scripts/sync_publishing_library.py --check
```

`metadata.json` preserves level/format/palette/verb targets. The rebuild script maintains cover symbols, author IDs, fresh sentence IDs, vocabulary and glossaries. `Books.json`, `Library.dat` and the standalone `Introduction.dat` are generated together. No JSON parsing is introduced into app launch.

## Book-by-book index

| Storyteller | Level | Book | Premise |
| --- | --- | --- | --- |
| Pipa | A1 | The Journey of Pipa | Pipa leaves his design desk for the Americas, but a message from Argentina gives his journey a new purpose: finding the courage to answer in Spanish. |
| Musgo | A1 | The Door Beneath the Roots | A whisper under Musgo’s garden leads to his father’s forgotten spell, and a door that should never have been left shut. |
| Pipa | A2 | The Return Ticket | On the last train home, Pipa finds a ticket that belongs to someone who has been waiting much longer than he has. |
| Zumi | A2 | A Boat for a Fly | Zumi’s wings cannot carry him through the rain, and the first passenger on his experimental boat is a creature who cannot swim. |
| Luma | B1 | The Observatory Light | Luma climbs the hill to investigate a light in an abandoned observatory and discovers why its keeper refuses to let it go out. |
| Brasa | A1 | The Bell Without a Voice | Brasa has one hour to repair the village bell before the fog hides the returning fishing boats. |
| Tilo | B1 | The Notebook of Favours | Tilo discovers that someone has removed every name from the village’s book of favours, just when he needs to ask for help. |
| Pipa | A2 | The Map of Mistakes | Pipa’s carefully drawn guide sends everyone the wrong way, until one wrong turn reveals a place worth finding. |
| Nube | B1 | Three Roads and a Storm | Three travellers shelter beneath Nube, each insisting on a different road, while the storm makes their decision for them. |
| Mora | A1 | The Letters Without Names | Mora drops three letters into a puddle and must find their owners using the mysterious objects inside. |
| Brasa | A2 | Rain on the Stage | A storm threatens Brasa’s first performance, and his attempt to dry the roof creates a much bigger problem. |
| Faro | B1 | The Eyes on the Other Side | Faro and Benji investigate two glowing eyes beyond the farm fence, but the lookout notices something the owl has missed. |
| Pipa | A2 | A Stitch Before Dawn | Pipa must repair a stranger’s torn coat before the morning bus, but a hidden pocket changes what the repair means. |
| Musgo | B1 | The Room That Did Not Exist | A forbidden spell gives Musgo an extra room, but each visit costs him a memory of the cottage he loves. |
| Mora | A1 | The Price of a Story | Mora reaches the market where stories buy anything, only to discover that her favourite tale is not hers to sell. |
| Brasa | A2 | The Chair by the Window | Every guest avoids the empty chair in Brasa’s café, until a rain-soaked visitor recognises the name carved beneath it. |
| Mora | A2 | The Coin That Kept Returning | A strange coin follows Mora home after every purchase, bringing complaints from the entire market. |
| Brasa | A2 | The Visitor’s Soup | An unexpected guest cannot eat Brasa’s famous Sunday soup, and the little dragon has to change more than his recipe. |
| Tilo | B1 | The Voice Offstage | During Tilo’s silent film screening, an unseen voice starts correcting the story, and the audience demands to know who is speaking. |
| Musgo | B1 | The Midnight Beans | Musgo’s enchanted beans climb towards a locked attic, but harvesting them means breaking a promise to his oldest neighbour. |
| Luma | A1 | A Light for Two | Luma prepares supper for a new neighbour, but an unanswered invitation leaves her following a trail of tiny lights. |
| Tilo | A2 | The Smallest Part | Tilo promises everyone a place in his play, then discovers that one quiet volunteer does not want to be onstage at all. |
| Nube | B1 | What a Cloud Can Carry | Nube gathers souvenirs from every village until the weight of his memories prevents him from leaving the ground. |
| Zumi | A2 | The Library That Flew | Zumi’s flying library cannot lift a single book, so his smallest readers help him rethink the invention. |
| Musgo | A2 | The Seed Looking for a Home | A seed refuses every pot Musgo offers it, leaving muddy footprints towards a house nobody visits. |
| Zumi | B1 | The Greenhouse Clock | Zumi must discover why the greenhouse has sealed itself shut before its plants wilt in the heat. |
| Luma | B1 | The Garden That Lost Its Blue | A moth follows a stolen colour into an unfinished painting. |
| Faro | A2 | The Basket Beneath the Bridge | Faro and Benji follow muddy footprints to a secret midnight meal. |
| Mora | A1 | Two Carrots and a Dragon | Mora’s shopping trip becomes an unexpected lesson in feeding a very small dragon. |
| Zumi | A2 | The Race Without Wings | Zumi’s fastest invention takes him further than his tired legs can carry him home. |
| Brasa | A2 | The Lighthouse Keeper’s Toast | Brasa arrives at a farewell party just as the lighthouse goes dark. |
| Luma | B1 | The Bridge of Questions | A curious fox finds that knowing the right question matters more than having a quick answer. |
| Faro | A1 | The Missing Page | Foxy borrows an adventure with no ending and sets out to find its missing page. |
| Faro | B1 | The Bell Monster | Faro follows a terrifying farm legend into the one place his neighbours refuse to enter. |
| Pipa | A2 | The Backpack of Goodbyes | Pipa misses his bus because one goodbye is more difficult than all the others. |
| Pipa | B1 | The Hidden Label | A celebrated designer offers Pipa success on one uncomfortable condition. |
| Pipa | A2 | The House with a Different Door | After years travelling, Pipa returns home and discovers that coming back is another kind of adventure. |
| Nube | A2 | The Tuesday That Never Came | Nube keeps postponing a visit until a strange calendar starts erasing the days. |
| Faro | B1 | The Cow on the Other Side | Two farms claim the same missing cow, and Faro must listen beyond their argument. |
| Musgo | B1 | The Box of Night | Musgo steals a piece of darkness to finish a spell and finds something alive inside it. |
| Luma | B1 | The Staircase of Mist | Luma chases a light above the clouds and must find a way back before sunrise. |
| Nube | A2 | The Midday Shadow | Nube follows a moving shadow across a market and accidentally becomes part of a street performance. |
| Nube | B1 | The Harbour Without Land | Nube reaches a floating harbour whose residents are waiting for a captain who may never return. |
| Tilo | A1 | The Singing Suitcase | A station mix-up leaves Pipa holding a suitcase that refuses to stay quiet. |
| Tilo | A2 | A Table for the Moon | Brasa’s restaurant receives a booking from a guest who cannot fit through the door. |
| Tilo | B1 | The Last Rehearsal | An empty theatre becomes the setting for the performance Tilo least expected. |
| Mora | A2 | Ser: The Wrong Portrait | Mora’s portrait introduces someone she does not recognise. Practise identity and roles as she asks for a truer picture. |
| Mora | A2 | Estar: The Dressing-Room Door | Just before the show, Mora discovers that the smallest performer is missing. Practise location and temporary states in a backstage rescue. |
| Mora | B1 | Querer: Two Roads | Mora and Pipa want different journeys. Practise expressing wishes as they plan a farewell without treating it as a failure. |
| Faro | A2 | Dinner Above the Canal | In Bangkok, Faro follows the smell of dinner to a table that has no spare chairs. |
| Faro | A2 | The Beach Lantern | A quiet beach walk leads Faro to a fisherman searching for a message he cannot replace. |
| Faro | A2 | The Towel and the Ticket | Before leaving Thailand, Faro has one small promise to keep and very little time to keep it. |

## Validation

- Shared model tests exercise binary round trips, legacy DAT compatibility, malformed offsets, all bundled chapter/translation/vocabulary records, verb coverage, cached revision precedence and completion/reward preservation.
- Build scripts validate that all 52 IDs are covered exactly once and that generated JSON/DAT assets match the manuscripts.
- Full iOS source and test type-checking is separate from simulator execution. No claim of simulator/device runtime validation is made for this editorial change.
