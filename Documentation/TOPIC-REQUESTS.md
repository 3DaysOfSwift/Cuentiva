# Contribution topic requests

Contribute offers Write freely and Topic requests. The request board supports text search and an Outstanding only filter. Each request carries a stable ID, category, editorial priority, teaching brief, explicit scope, target, accepted/reviewed count, and demo-example count. Six seeded requests cover Haber, Tener, Ir, Ser, directions, and kind disagreement. Priorities are editorial suggestions, not analytics or live demand.

Coverage is complete when the accepted/reviewed count supplied by the topic repository meets its target. Demo examples and local submissions never increase that count. No request is falsely shown as approved in this offline demo. A future service must derive accepted coverage from validated, published books and perform review independently of author declarations.

Picking a request creates or resumes a linked draft on this device. This is not a global exclusive assignment. Freestyle writing remains available. Switching writing paths saves current work first; failure preserves the editor. Older drafts still decode. Topic ID, teaching note, and self-review checks persist through the existing contribution repository.

The author supplies an English teaching note and a Spanish story, self-checks the brief, and—where required—uses each listed form at least twice. Exact, accent-sensitive word counts are drafting aids only: they do not establish distinct examples, correct grammar, coherent teaching, plagiarism status, or publication readiness. Submit validates the checklist and saves Pending review locally, without uploading or publishing. A future reviewer must verify meaningful sentence use and explanatory quality before acceptance.

Haber’s first ticket scopes the requirement to the present auxiliary forms he/has/ha/hemos/habéis/han with participles. It also asks the author to distinguish existential hay and possessive tener. It does not claim to cover all tenses or regional variants. Habéis is the vosotros form; usted/ustedes use third-person forms.

Language references: [RAE on haber + participle and compound tenses](https://www.rae.es/gramática/sintaxis/cohesión-e-independencia-de-los-componentes-de-las-perífrasis-perífrasis-verbales-y-tiempos-compuestos), [FundéuRAE on impersonal haber](https://www.fundeu.es/recomendacion/habia-habian-muchas-personas-haber-uso-impersonal/). Editorial/native-speaker review is still required for production briefs and submitted stories.

Architecture: TopicRequestRepository isolates the request source; LocalTopicRequestRepository seeds the demo. ContributionManager owns eligibility and submission rules. ContributionViewModel manages editor and board state. TopicRequestBoard and TopicTeachingBrief are reusable themed components. No server URLs or artificial publication success are introduced.
