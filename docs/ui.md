# Server-driven UI documents

`CommandTower::UI` builds and validates `ui_document` trees in pure Ruby (no DB, no Messaging dependency). A document is a closed catalog of primitives, token enums, and one `textFallback` string. Nothing in the engine renders a `ui_document` to an HTTP response yet: the Inbox `content` field is still `inbox_document_v1` (see [api_reference.md](api_reference.md#me-inbox)). This guide covers authoring, limits, the email renderer, and the catalog header.

## Primitives

The Builder has one method per catalog primitive. Nodes live in `lib/command_tower/ui/nodes/`.

| Primitive | Purpose |
|-----------|---------|
| `stack` | Vertical container (`gap`, `align`). There is no row or direction. |
| `card` | Container with `surface`, `tone`, `padding`. |
| `facts` | Container for a fact block. |
| `divider` | Rule. |
| `text` | Spans (plain, `strong`, `link`) with `variant`, `textTone`, `maxLines`. |
| `time` (`instant`) | An instant rendered per viewer or by the server formatter. |
| `key_value` | Labelled items; `time` inside returns a node used as an item value. |
| `badge` | Short label with a `tone`. |
| `button` | Label plus a `navigate` action; `variant`: primary, secondary, ghost. |
| `image` | `https` only, host must be in `config.ui.image_hosts`; `alt` required unless `decorative`; `aspect` required. |
| `banner` | Spans with optional title and `tone`. |
| `avatar` | `src` or `initials`, size sm, md, lg. |
| `stat_tile` | Value and label. |
| `code` | Sensitive value (`qr` or `text`). Never reaches derived text, legacy mapping, email, `inspect` or validation errors. |
| `component` | Registered native component by `key`, with a required `fallback` tree. At most one per document. |

The `navigate` action takes exactly one destination: `path:` (internal, starts with `/`, not `//`) or `href:` (external: https, mailto, tel; no userinfo). Wire form: `{ type: "navigate", destination: { kind: "internal", path } | { kind: "external", href } }`.

## Tokens

Enums are in `CommandTower::UI::Tokens`; the design mapping (spacing px, type steps, tone palette keys, tint alphas, avatar px, zone abbreviations) is runtime data in `lib/command_tower/ui/tokens/ui_token_mapping.json`.

| Token | Values |
|-------|--------|
| `gap` | none, xs, sm, md, lg, xl |
| `tone` | neutral, accent, success, warning, danger |
| `textTone` | primary, secondary, muted, accent |
| `variant` (text) | display, heading_xl, heading_l, heading_m, title, subtitle, body, caption, overline, mono |
| `surface` | raised, tinted, plain |
| `align` | start, center, end, between |
| `avatar size` | sm, md, lg |

Rules worth knowing:

- **`stack.align`:** absent stretches children across the cross axis; `start`, `center`, `end` set cross-axis alignment; `between` is main-axis space-between. `badge` and `avatar` children always hug their content.
- **No warning, success or danger text tones.** `textTone` is limited to the four above because those three fail contrast as text. They remain valid as container, badge and banner `tone`.
- **Badge contrast caveat.** Badges are solid: white text on a solid tone fill. White on the solid success (green) badge is about 4.1:1 in light and 3.2:1 in dark, below the 4.5:1 text threshold, and the dark danger badge is also low. Do not rely on a badge to carry meaning alone; pair it with text or an icon. See the design contrast notes (states.md 8 A3).
- **Unknown tokens.** They raise `InvalidTokenError` in development and test. In production they fall back to the default and log the path.

## Composing

Three layers, all by constant (there is no registry):

```ruby
class ClassCanceled < CommandTower::UI::Composer
  def compose(d, starts_at:)
    d.card { |c| c.text "Class canceled" }
  end
end

ClassCanceled.call(starts_at: time) # => CommandTower::UI::Document, validated
```

- `UI.document(text_fallback:) { |d| ... }` builds a `Document` with exactly one root. It is not validated; call `validate!`.
- `Composer` (`lib/command_tower/ui/composer.rb`): implement `compose(d, **inputs)`; `.call` validates the tree, derives `textFallback` with `TextDerivation`, and validates again. Override `text_fallback(root, **inputs)` to supply your own string.
- `Fragment` (`lib/command_tower/ui/fragment.rb`): declare inputs with `attribute` and `validates`; `compose(b)` emits primitives. Use with `d.fragment(MyFragment, **inputs)`. Invalid inputs raise `InvalidFragmentError` with attribute names and codes only.

Validation errors (`InvalidDocumentError#details`) carry node paths and codes only, never values.

## Fragment library

`CommandTower::UI::Fragments`:

| Fragment | Emits |
|----------|-------|
| `Header` | Vertical header: optional avatar and badge, then title and subtitle. |
| `FactRow` | One `key_value` with a single labelled string value. |
| `Facts` | Base class for a host fact block. `Facts.call(builder, metadata:)` emits exactly one `facts` node; subclasses implement `compose(b, metadata:)`. |
| `CtaGroup` | Stacked buttons: the primary first, then up to two secondaries. |
| `NoticeFrame` | Tinted card with a title and body paragraphs. Informational only. |

## Time formatter and abbreviation rule

`TimeFormatter.call(at:, zone:, format:, label: :auto)` renders an instant for an IANA zone: en-US, 12-hour clock, no leading zeros, uppercase AM/PM, plain U+0020 separators.

| Format | Example pattern |
|--------|-----------------|
| `short` | `Mon, Nov 23, 4:05 PM` |
| `long` | `Monday, November 23, 2026 at 4:05 PM` |
| `date` | `Mon, Nov 23` (never labelled) |
| `time` | `4:05 PM` |
| `countdown` | App-only; the server renders it as `short`. |

On the server the zone label is always shown for every format except `date`, unless `label: :never`. The label comes from `ZoneAbbreviation` and the `zoneAbbreviations` / `ambiguousAbbreviations` / `tzdataVersion` data in the token mapping. Regenerate it inside Docker with the engine task `app:command_tower:ui:zone_abbreviations` (`YEAR=` pins the generation year).

## User zone

A `time` node, `TimeFormatter`, `TextDerivation` and `Email::Renderer` accept `zone: :user` (wire value `"user"`). The server resolves it to the `user_zone:` keyword, which defaults to `config.ui.default_zone`; the app resolves it to the device zone. A `:time` fact node without a zone renders in the render zone.

## Message profile

`Document#validate!(profile: :message)` adds one rule to the default checks: the document has exactly one `facts` node. The default profile is unchanged.

## Redaction

`UI::Redaction.call(document, impersonating:)` returns a new document in which every `code` node becomes a `text` node reading "Open the app to check in" (variant `body`, `textTone: secondary`, label dropped), so the code value never reaches the serialised document. Only `impersonating: false` skips it; any other value redacts.

## Required facts

`UI::RequiredFacts::Verdict.call(texts:, metadata:, required_facts:, render_zone:)` is a pure check for specs and the gallery (never the send path). It returns `[{ channel:, fact_key:, passed: }]`, one row per text and required fact.

- `texts` maps channel to rendered text. Callers leave out `headline` and `pushover_title`.
- Each required fact is a hash: `key:`, `matcher:` (`:text`, `:time` or a host matcher), `zone:` (metadata key holding an IANA zone, or `:user`) and `optional:`. An optional fact with no metadata value yields no rows.
- `:text` passes when the metadata value is a substring of the text. `:time` passes when the `:time`-preset rendering (for example "6:00 AM PT") in the fact's zone is a substring; `:user` and a missing zone use `render_zone`.
- Host matcher protocol: any object responding to `call(text:, metadata:, t:)` and returning a Boolean. `t` is `t.call(at, zone:, format: :short, label: :auto)`, backed by `TimeFormatter` with `render_zone` as the user zone.

## Limits

`CommandTower::UI::Limits`, mirrored by `spec/fixtures/ui/wire_hardening.json` for the frontend normalizer:

| Limit | Value |
|-------|-------|
| Nodes | 200 |
| Depth | 8 |
| Serialized bytes | 64 KiB |
| String length | 2,000 |
| `textFallback` length | 8,000 |
| Spans per text | 50 |
| `key_value` items | 50 |
| Nodes in `facts` | 100 |

Paths and links are hardened by `Hardening` (shared cases in `wire_hardening.json`); rejections return codes, never the rejected value.

## Email renderer

`CommandTower::UI::Email::Renderer.call(document, palette:, origin:, **chrome)` returns `Output(html, text)`: table-based, inline-styled HTML plus a plain-text part. Chrome keywords: `footer_html:` (trusted, escaped HTML), `app_name:`, `preheader:`.

- Escaping uses ActionView's TagHelper; document values are never interpolated into markup.
- `code` nodes raise `InvalidDocumentError` (a check-in code never reaches an email).
- Conversions: `component` becomes its fallback tree; internal `navigate` becomes `origin + path`; `countdown` becomes `short`; icons are dropped; a ghost button becomes an underlined link; image width and height derive from `aspect`.
- Text colour comes from `textTone`.
- The caller supplies `palette:`. Emails for MessageDefinition-backed types resolve it with `CommandTower::EmailTheme::Palette.resolve` (see "Email token file").

### Email token file

The 13-key palette comes from the first source that exists:

1. The host token file `config/ui_tokens.json` under `Rails.root`.
2. A customised `config.email_theme` (the 9 legacy keys map onto palette keys; `muted`, `success`, `warning` and `danger` come from the CT default).
3. CT's default file, `lib/command_tower/email_theme/default_ui_tokens.json`.

File format: `{ "version": 1, "palette": { "<token>": "#RRGGBB", ... } }`. `version` must be `1`. `palette` must carry every key in `UI::Email::Styles::PALETTE_KEYS` (13 keys) as `#RRGGBB`; extra tokens are ignored. The frontend export bin writes the file (`ct-export-email-tokens`).

At boot, an invalid host file raises (the message names keys, never values). A missing host file logs one warning and email falls back to sources 2 and 3. When the host file exists, `EmailTheme::Resolver` derives the 9 legacy keys from it.

Mailer previews for defined types: `/rails/mailers/message_definition/sample_email`, `sample_email_fallback` (composer failure, CT fallback document), `sample_email_user_zone`, `sample_email_promotional` (promotional footer with postal address) and `sample_email_without_api_base_url` (footer when one-click headers are omitted) (rails_app dummy app). Footer and header contract: [messaging_integration_guide.md](messaging_integration_guide.md#email-compliance-defined-types).

## Legacy mapping

`UI::LegacyMapping.call(document, legacy_presentation_keys: [])` maps a catalog-2 document to `inbox_document_v1` blocks through `InboxDocument.compose`: text to `paragraph`, button to `cta` with a typed destination (https, mailto, tel only), time to `instant`, a `component` whose key is in `legacy_presentation_keys` to `presentation`, containers by mapping children, other nodes to a derived-text paragraph or dropped, `code` always dropped. No caller uses it yet.

## Catalog header

Clients send `X-UI-Catalog: <n>`. `UI::Catalog.from_header` returns `1` for a missing, blank, non-integer or non-positive value and clamps higher numbers to `UI::CATALOG` (currently `2`). `HttpBoundary` passes the result into `with_execution`, and it is available as `CommandTower::Current.ui_catalog` (default `1`; nested `with_execution` keeps the outer value).

It changes only Inbox read responses for types registered with a `message:` MessageDefinition: catalog 2 or higher returns the validated `UI::Document` (`ui_document`), catalog 1 returns `inbox_document_v1` through `UI::LegacyMapping`. Undefined types return the same `inbox_document_v1` for every catalog. The header is never read for authorization. Inbox read responses (list, show, open, conversation) set `Cache-Control: no-store`.

Push, SMS and Pushover for defined types are built from the slots stored at Accept (`headline`, `push_body`, `sms_body`, `pushover_title`, `pushover_message`), not from the catalog; undefined types keep the generic templates.

See [api_reference.md](api_reference.md#me-inbox) and the CORS note in [bootstrap/11-auth-client-path.md](bootstrap/11-auth-client-path.md). See [api_reference.md](api_reference.md#me-inbox) and the CORS note in [bootstrap/11-auth-client-path.md](bootstrap/11-auth-client-path.md).

## Producer contracts

- **`textFallback` excludes `code`.** Derived text never includes a `code` value; an overriding `text_fallback` must not either.
- **QR needs a text alternative.** A `code` node with format `qr` must be paired by the producer with a way to read the same information without scanning (a `text` code, or labelled instructions). The engine does not add one.
- **Link text versus host.** Link text is producer-controlled and is not checked against the destination host. Do not show a trusted-looking hostname as link text for a different destination.
- **Image hosts are enforced server-side.** `image` and `avatar` `src` must be https on an exact host in `config.ui.image_hosts` (lowercased, IDN-normalized); anything else fails validation. Clients should not treat the allowlist as their only line of defence, but they are not expected to re-implement it.
