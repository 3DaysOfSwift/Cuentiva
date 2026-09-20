# Verb Training: day-20 gift

Implemented 20 September 2026. This feature is bundled and offline; no AI, network, coin purchase or new database is involved.

## Data audit and coverage

The previous library had three verb-focused books (ser, estar, querer), with mainly present-tense teaching metadata. Their stories remain unchanged. They were not a complete conjugation catalogue.

The new editable source is `content/verbs/catalogue.json`. `python3 scripts/build_verb_tables.py` compiles it into `VerbTables.swift`; `--check` verifies that source and app agree. The Swift table is shared by the app and the model test target without a runtime JSON dependency.

There are 29 core verbs: ser, estar, ir, tener, comer, beber, pedir, pagar, comprar, ganar, trabajar, preguntar, saber, conocer, aprender, estudiar, pensar, conducir, caminar, pedalear, portarse, enseñar, entrenar, escribir, necesitar, hacer, decir, querer and poder.

The eight practice time frames are present, preterite, imperfect, simple future, ir a + infinitive, conditional, present perfect and pluperfect. Nine subject choices map to all six conjugation slots, including feminine third person, usted, ustedes and Spain's vosotros. This produces 2,088 short bilingual combinations, plus eight longer authored scenes.

The reference additionally covers future perfect, conditional perfect, present and past subjunctive (-ra and -se), perfect and pluperfect subjunctive (both past alternatives), affirmative/negative commands, participles and gerunds. Commands deliberately have no yo form. Vos forms, the historical future subjunctive and pretérito anterior are not included. Reference coverage is broader than the beginner sentence game; the UI does not claim to teach every regional or historical form.

Conjugation reference sources:
- [RAE / ASALE: Spanish conjugation](https://www.rae.es/buen-uso-español/conjugación-española)
- [RAE student dictionary: conjugation tables](https://www.rae.es/diccionario-estudiante/docs/conjugaciones-verbales.pdf)
- [RAE: pagar](https://www.rae.es/dpd/pagar)

The examples are original. Automated completeness, playability and independently specified irregular-form checks are not a substitute for a fluent Spanish editor's final release review. In particular, do not market this as assessed CEFR mastery.

## Game behaviour

- Eligibility and the Debug preview are unchanged by the workout redesign.
- The system selects each sentence automatically: verb, subject and time frame are randomized. Mixed-verb scenes appear roughly one rep in six. The next sentence cannot repeat the immediately previous sentence.
- A workout set has 12 reps. Generate sentence after the twelfth rep begins another set. The total number constructed and persisted history remain; there is no daily limit or coin charge.
- Every answer word is present at the start, with duplicate occurrences represented by separate tiles. An equal number of randomly selected distractors is added, excluding normalized answer words. The full cloud is shuffled once.
- Correct tiles become inactive in their original positions. No replacement tile reveals the next answer. Incorrect taps do not advance or destroy the sentence.
- Completion reveals the highlighted Spanish sentence and a chart for each distinct verb, including supporting verbs (ir, haber, leer) and infinitives/gerunds in the sentence. Authored scenes use explicit token annotations; generated sentences use their construction metadata. Ambiguous words such as fui are not guessed from spelling.
- Base verbs use the theme’s gold colour; used conjugated forms use its accent and an underline. Labels explain the distinction without depending on colour alone. Charts appear with an insertion transition; Reduce Motion disables the animation.
- Generate sentence sits after the current charts and before the sentence trail. The latest 12 previous solutions and charts appear newest first; the current completed solution is not duplicated in the trail. The old 100-item trimming rule has been removed; already-trimmed historical items cannot be reconstructed.
- There are no pickers, Stop for now, Say it again, or “sentence saved” messages. Persistence only supports counters, the visible trail and interruption recovery.
- Verb practice counts as a practice day, but does not grant a book-completion streak, coin, or reading reward.

## Persistence and testing

Optional progress fields preserve old files. State and gift flags use the existing atomic progress repository and shared SwiftData container. Round ID and expected word position reject duplicate/late taps. Failed saves leave the prior draft and counters unchanged.

Tests cover day 19/20, access rejection, duplicate gift claims, save failure/retry, relaunch, repeated practice, stale taps, reset, unchanged balance and streak, every playable phrase, all reference slots, key irregular/reflexive spellings and presentation outcomes. See API-COVERAGE.md for runtime limits.

## Testing before day 20

In a Debug build, open Settings → Developer testing → Enable Verb Training now. The Verbs tab appears immediately; Open Verb Training launches it from Settings too. The override is saved separately, leaves practice-day counts and earned gift flags intact, and is ignored in Release builds. Disable the preview from the same section to test the normal gate again. Library purchase access is still required.

### Alternating focused sets

New workouts begin with a focused set; each completed 12-rep set switches between focused drills and the existing sentence generator. Existing interrupted sentence sets finish before switching. The selected mode, verb and tense persist with the workout.

Focused sets use seven core verbs (comer, beber, ir, pedir, pagar, comprar, querer), with present, past and future sets. Querer uses the imperfect for its past practice. Six first-person reps establish one form, followed by six reps varying the subject. Short authored complements keep sentences within five words. The cloud contains all answer words plus two distractors. Feedback stays compact until the final rep reveals the conjugation chart; focused history entries stay compact. There is no new picker, tab, price or reward rule.

### Daily workout presentation

Opening Verbs refreshes the local calendar day without generating a sentence. A fresh day shows “Start today’s Verb workout”; pressing it starts the set. Same-day unfinished sets resume, and completed sets show a completion summary of the latest 12 sentences, newest first. “Practise more” explicitly starts the next alternating set. The lifetime constructed count remains stored but is no longer shown. A new day clears the current exercise while preserving all history and totals; undated existing workouts retain their current state on upgrade.

### Completion celebration

After rep 12, “Complete Verb Training” opens a dedicated celebration. It lists distinct verbs from the latest 12 sentences and counts past/future expressions, including repeats. Compound forms count once; ir + a counts as future. Continue persists acknowledgement before returning to the completed-day summary, with retry on save failure. Completed sessions awaiting acknowledgement retain the completion button after relaunch.
