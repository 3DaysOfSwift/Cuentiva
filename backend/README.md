# Cuentiva text catalogue API — Wix setup

Status: code and local tests only; **not deployed to Wix**. No collections, secrets
or website files have been changed. This is administrator-controlled catalogue
publishing and iOS download sync, not public author uploads or an AI moderation system.

## Install in your Wix site

1. In the CMS for site `59047474-e384-4a44-a850-2d0cc36f1e0e`, create a multiple-item
   collection with the exact **Collection ID `CuentivaCatalogue`**.
2. Set **read/create/update/delete permissions to Admin only**. Do not connect this
   collection to a public page or dataset. The backend exposes approved releases.
3. Add these fields (field IDs, not display labels):

   | Field ID | Type |
   | --- | --- |
   | kind | Text |
   | release | Text |
   | payload | Text |
   | part | Number |
   | ready | Boolean |

   Wix supplies `_id`. Do not index `payload`; an index on `kind, release` can help.
4. Add `wix/catalogue.js` to the site's **backend/catalogue.js**.
5. Add `wix/http-functions.js` as **backend/http-functions.js**. If that file already
   exists, merge its imports and the two `cuentivaCatalogue` functions plus helpers;
   do not overwrite other APIs. Neither file belongs in page/frontend code.
6. In Wix Secrets Manager create **CUENTIVA_PUBLISH_TOKEN** with a securely generated
   random value of at least 32 characters. Keep it in your password manager; never
   put it in Git, the app, page code, screenshots or a chat message. This key authorizes
   catalogue publication. The endpoint uses Wix v2 Secrets API with backend elevation.
7. Review and publish the site. Publishing can include other saved site changes;
   check those first. No new public web pages are required.
8. The app's configured URL is:
   `https://www.3daysofswiftconcurrency.com/_functions/cuentivaCatalogue`
   Confirm the custom domain is attached to this site. A 503 JSON response saying
   `Catalogue not published` is expected before the first upload.

## Upload the reviewed bundled books

Requires Node 22+; no npm packages required. From the repository root, set these
locally (do not paste your real token into the command example in source control):

```sh
export CUENTIVA_ENDPOINT='https://www.3daysofswiftconcurrency.com/_functions/cuentivaCatalogue'
read -s 'CUENTIVA_PUBLISH_TOKEN?Publishing token: '
export CUENTIVA_PUBLISH_TOKEN
node backend/tools/publish.js
unset CUENTIVA_PUBLISH_TOKEN
```

The hidden `read` syntax above is for macOS zsh. The script reads the existing
`Books.json`, validates it, sends UTF-8 text in chunks and activates the release
only after the server verifies its complete checksum and schema. You can pass an
alternative reviewed Books.json path as the first argument. Repeat the same upload
safely after an interruption; identical immutable chunks are accepted again.
Uploads of a different payload under an existing part ID fail. Never change book
or sentence IDs merely to edit copy—IDs connect existing reading progress.

## API contract, schema 1

All **application request/response bodies** are at most **1,024 UTF-8 bytes**.
This is not a promise about network packet size: HTTP/TLS headers, cookies and
Wix-generated error pages add overhead. The client rejects oversized responses.
Images, files and arbitrary JSON fields are not supported. Illustrations stay in
the app. Only fictional demo locations are permitted in this first public feed;
real users' precise submission coordinates must never enter it.

- `GET /_functions/cuentivaCatalogue`: manifest `{schema,version,bytes,chunks,books}`.
- `GET ...?version=<sha256>&part=<zero-based index>`: raw UTF-8 text part.
- `POST ...?action=begin`: manifest JSON, Bearer publishing token required.
- `POST ...?action=part&version=...&part=...`: text body, same token.
- `POST ...?action=publish&version=...`: empty body, same token.

The SHA-256 version identifies the exact compact JSON byte stream. Each published
release is immutable. The active pointer changes after verification, so a client
can finish its pinned release while a new one is published. Old releases remain
available; implement revocation and retention before accepting public user content.
Admin uploads are treated as already editorially reviewed. JSON validation is
**not** AI/content moderation. There is no author account creation, banning, report
queue, or self-publication endpoint in this initial service.

The public GET feed is readable without a member account. StoreKit still gates the
app UI, but this feed does not enforce paid access or Nearby location restrictions
against direct API callers. That matches an open text catalogue; add authenticated
server-side authorization before using it for restricted content.

## App behaviour

- Launch reads the last verified cache, or bundled books if no usable cache exists.
- Sync happens after local content loads and on foreground; Settings → Community
  library → Update library retries manually.
- Unchanged manifest: one small request, no book downloads.
- Changed manifest: four bounded concurrent requests, complete checksum/schema
  validation, then one atomic cache write and replacement of the whole library.
- Matching IDs replace existing books; no concatenation or duplicate entries.
- Books absent from the new catalogue disappear from the library. Their progress
  records and historical Books Learned total remain; they will reconnect if restored
  under the same IDs. The free introduction `cafe` must always exist.
- Interrupted, invalid or failed saves preserve the last usable catalogue. A corrupt
  cache falls back to the bundle. Progress and drafts are never uploaded by sync.

The seed currently contains 52 books and about 471 KB of compact JSON, requiring
roughly 461 small downloads on first sync. This is deliberately small per response,
not necessarily faster than larger batched/compressed transfers. There is no delta
sync or partial-download resume yet; unchanged releases are skipped, failed changed
releases are retried as a whole. Catalogue limit: 1 MiB / 500 books. Wix quotas and
runtime limits must be measured on the site's plan before increasing those limits.

## Run tests locally

```sh
node --test backend/tests/*.test.js
swift test --disable-sandbox
```

`tools/server.js` is an in-memory loopback-only integration server (port 8787).
It requires a temporary CUENTIVA_PUBLISH_TOKEN, uses the same release service and
is intentionally not a production host. The app requires HTTPS and should use Wix.

References:
- https://dev.wix.com/docs/develop-websites/articles/coding-with-velo/integrations/exposing-services/write-an-http-function
- https://dev.wix.com/docs/velo/apis/wix-secrets-backend-v2/secrets/get-secret-value
- https://dev.wix.com/docs/velo/apis/wix-data/introduction
