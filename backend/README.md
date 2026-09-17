# Library delivery moved to GitHub

Wix is no longer part of Cuentiva's library delivery. The old, undeployed Wix API,
CMS publisher and development HTTP server have been removed.

The standalone source repository is:
https://github.com/3DaysOfSwift/GlobalEnglish-SpanishLearningBooksCollection

Its `content/` directory holds books and authors. Tests and a deterministic builder
produce self-contained packs of up to 13 books, with SHA-256 checksums. A manual
GitHub release workflow publishes the index and pack files together.

Cuentiva uses `GitHubCatalogueTransport` to fetch the latest release's catalogue and
only missing or changed packs. Verified local packs, atomic index replacement and
bundled fallback remain. No authentication token is shipped in the app.

See that repository's README for the schema, publication and review process,
licensing status, preservation guidance and current capacity limits. Remote repository
creation and initial publication must succeed before online sync is available.
