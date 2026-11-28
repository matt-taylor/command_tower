# Messaging with CommandTower

CommandTower owns modern messaging **platform** surfaces. Hosts supply product content, channel policy, and adapter credentials.

Complete install and host RBAC first: [Bootstrap a new host](bootstrap/README.md) (through [`12-smoke-check.md`](bootstrap/12-smoke-check.md) before emitting or wiring phone/Pushover).

## Current surfaces

| Concern | Path / entry |
|---------|----------------|
| User inbox (consume) | Engine `/me/inbox*` — see [API reference](api_reference.md#me-inbox) |
| Preferences | Engine `/me/preferences*` — see [API reference](api_reference.md#preferences) |
| User inbox conversation | Engine `GET /me/inbox/conversation` — see [API reference](api_reference.md#me-inbox) |
| Phone / Pushover / Push endpoints | Engine `/me/phone*`, `/me/pushover*`, `/me/push*` (503 when capability unavailable) |
| Single-recipient emit | `CommandTower::Services::Messaging::Communications::Produce` |
| Multi-recipient emit | `CommandTower::Services::Messaging::Communications::ProduceMany` |
| Admin cohort announce | Engine `POST /admin/messaging/announcements` |
| Host ops announce | Host-owned rake/job (product-specific; not part of the gem) |

Authentication uses JWT bearer or cookie session as documented in [Authentication](authentication.md). Me Inbox authorization requires host RBAC entities (dummy host uses a `member` role mapping). Admin announcements use entity `admin_messaging_announcements` (engine `default.yml` admin group).

## Produce (single recipient)

Call from a **product workflow**, not from a controller service bypass:

```ruby
CommandTower::Services::Messaging::Communications::Produce.call(
  user: user,
  notification_type_key: "welcome",
  host_event_identity: "welcome/#{user.id}/#{SecureRandom.uuid}",
  title: "Welcome",
  body: "Thanks for joining.",
  platform_enabled_channels: [:inbox, :email],
  metadata: { source: "onboarding" } # optional
)
```

| Kwarg | Required |
|-------|----------|
| `user` | yes (`User`) |
| `notification_type_key` | yes (`String`) |
| `host_event_identity` | yes (`String`) |
| `title` | yes |
| `body` | yes |
| `platform_enabled_channels` | yes (`Array`) |
| `metadata` | no (`Hash`) |
| `conversation_key` | no (`String`) — groups inbox items into one conversation |
| `conversation_title` | no (`String`) |
| `collapse_key` | no (`String`) — push collapse identity, see [Push collapse key](#push-collapse-key) |

`Produce` fails with a validation error when the registered type declares `deep_link_required` and `metadata` has no non-blank `deep_link`.

## ProduceMany (multi recipient)

| Kwarg | Required / notes |
|-------|------------------|
| `user_ids` | yes (`Array` of integer ids) |
| `notification_type_key` | yes |
| `campaign_identity` | yes — fan-out builds `host_event_identity` as `"#{campaign_identity}/#{user.id}"` |
| `title`, `body` | yes |
| `platform_enabled_channels` | yes |
| `metadata` | optional |
| `conversation_key`, `conversation_title` | optional (`String`), applied to every recipient's item |
| `execution_mode` | optional, default `:async`; `:sync` capped at **25** recipients |

Admin announcements HTTP is a product path over ProduceMany (async/sync, audience selection). Contract: [API reference — Admin messaging](api_reference.md#admin-messaging).

## Rendering template overrides

`ChannelRenderer` resolves each rendered destination (email HTML/text, SMS, Pushover, push) by `notification_type_key` first, falling back to a generic template — and always prefers a **host** view over CommandTower's own engine default for either. Hosts customize by dropping ERB files at this path in their own `app/views/`; they never call `ChannelRenderer` or its internal `TemplateResolver` collaborator directly.

```text
app/views/command_tower/messaging/rendering/
  email.html.erb            # optional host override of the generic chrome
  email.text.erb
  sms.text.erb
  push.text.erb
  pushover.text.erb
  <notification_type_key>/
    email.html.erb          # optional type-specific override (only if the key matches [a-z0-9_]+)
    email.text.erb
    sms.text.erb
    push.text.erb
    pushover.text.erb
```

Notes:

- `<notification_type_key>` directories only resolve when the key matches `/\A[a-z0-9_]+\z/`. Keys with dots (e.g. legacy `"example.type"`-style keys) or other characters always fall back to generic — they never attempt a type directory, even if one happens to exist on disk.
- Each rendered destination resolves independently — a type directory can override just `email.html.erb` while every other destination (email text, SMS, Pushover, push) still renders from the generic templates.
- Generic templates receive the same four locals as before (`title`, `body`, `deep_link`, `h` — an HTML-escaping helper). Type-specific templates additionally receive `metadata` (the communication's metadata Hash) and `notification_type_key`.
- A missing or failing template (generic or type-specific) surfaces the same way it always has: `RenderError` with code `"render_failed"`.

### Inbox document (no ERB override)

The Me Inbox detail `content` field (`inbox_document_v1`, see [api_reference.md](api_reference.md#me-inbox)) is built by `InboxDocumentRenderer`. An `inbox_document.json.erb` view is **not** read (the override was replaced). A notification type customizes the document through `declaration.inbox_document_composer`, a pure-Ruby class called with `communication:` that returns an `InboxDocument`. The generic document is built in Ruby from `communication.body` and `metadata`. A missing, raising, or invalid composer falls back silently to the generic document — the Inbox read path never surfaces a `RenderError` and never 500s.

### Inbox contract reads for Home Notices

`CommandTower::Messaging::Contract::Inbox.document_for_communication(request)` takes `Requests::DocumentForCommunication` (`communication_id:`, `recipient_id:`, `impersonating:`) and returns `Results::InboxDocument` (`communication_id`, `inbox_item_id`, `document`: the catalog 2 `UI::Document`). It returns `nil` when the communication is missing, not the recipient's, deleted or archived, not inbox-backed, or its type has no `MessageDefinition`. It is read-only and emits no audit. Home Notices use it to render a linked delivery ([home_notices.md](home_notices.md#deliver)); `viewed_for_communication?` and `mark_viewed_for_communication` are unchanged.

**Resolving an item.** `CommandTower::Messaging::Contract::Inbox.resolve_for_event(request)` and `unresolve_for_event(request)` take `Requests::ResolveForEvent` (`recipient_id:`, `notification_type_key:`, `host_event_identity:`; the key and identity must be non-blank, otherwise `Contract::ValidationError`) and return `Results::InboxResolution` (`communication_id`, `inbox_item_id`, `resolved`, `changed`), or `nil` when the recipient has no live inbox item for that event. Resolving sets `inbox_items.resolved_at`: a resolved item leaves the list, the unread count and the push badge, and a conversation whose members are all resolved returns `404`. The item stays readable by id (`GET /me/inbox/:id`, `POST /me/inbox/:id/open`), so an old push tap still opens it. Both calls are idempotent (`changed` is `false` on a repeat), never touch `viewed_at`, and emit no audit: the calling host owns the audit decision. Badge sync is scheduled by the scheduler, which is a no-op while impersonating.

## Me Inbox HTTP (summary)

| Concern | Contract |
|---------|----------|
| List | `GET /me/inbox?limit=&offset=&scope=` — conversation/entry rows, meta `{ limit, offset, totalCount }` |
| Conversation | `GET /me/inbox/conversation?key=&scope=` (+ one of `around`/`before`/`after`, `limit`) |
| Detail / open / archive / delete | `/me/inbox/:id` (+ `open`, `archive`). Open marks viewed on first non-impersonated view and audits once (`messaging_inbox_item_viewed`). For defined types while impersonating (or unknown types), show, open and conversation return `metadata: null` and `content` with `code` nodes replaced (`UI::Redaction`) |
| Bulk | `POST /me/inbox/bulk/{read,unread,archive,restore,delete}` with body `ids` |
| Unread | `GET /me/inbox/unread-count` — `{ count, badgeCount }` |

Detail `content` is `inbox_document_v1` with blocks `paragraph`, `cta` (typed `destination`: internal `path` or external `href`), `instant`, and `presentation`. The `X-UI-Catalog` request header is accepted and defaults to `1`; it changes Inbox `content` only for types registered with a `message:` MessageDefinition (catalog 2 or higher returns `ui_document`); undefined types return `inbox_document_v1` for every catalog, and Inbox read responses set `Cache-Control: no-store` ([ui.md](ui.md#catalog-header)). Hosts never expose `inboxEnabled` as an inbox switch to users outside the preferences contract.

Pagination detail: [pagination.md](pagination.md). Full catalog: [api_reference.md](api_reference.md#me-inbox).

## Restoring an archived thread on a new message

`config.messaging.inbox.restore_archived_thread_on_new_message` (default `false`, so archived threads stay archived). When `true`, a genuinely new inbox item that carries a `conversation_key` restores the recipient's archived, non-deleted, non-resolved items in the same conversation. The restore runs after commit, in its own locked transaction with a deadlock retry. An idempotent replay of the same event never restores. Restoring brings back archived unread members too, so one new message can raise the unread count by more than one.

## Push collapse key

`collapse_key` (optional `String`, on `Produce` and the Accept path) is sent to Expo as `collapseId` on the push message. It is a delivery hint: it is not part of the request fingerprint, so changing it does not make a new event.

- Format: starts with a letter or digit, then letters, digits, `.`, `_`, `:` or `-`; 64 characters at most. Anything else fails validation. Blank is stored as `nil`.
- It is never derived from `conversation_key`. A conversation outlives any one notification, so the producer chooses the key per notification that should replace another.
- iOS replaces an earlier delivered notification that has the same `collapseId`. Android collapse behaviour is governed by the Expo/FCM collapse rules and not guaranteed to replace a notification already shown; do not rely on it for correctness.
- Shared-key warning: every push with the same key collapses into one, across types and conversations, for that device. Namespace the key (for example `<type>:<entity_id>`) and never reuse one key for unrelated notifications, or one will silently replace the other.

## Email compliance (defined types)

Emails for types registered with a `message:` MessageDefinition carry a compliance footer and, when eligible, RFC 8058 one-click unsubscribe headers. Undefined types get neither (their ERB templates are unchanged).

**Config** (`config.messaging.compliance`):

| Key | Purpose |
|-----|---------|
| `api_base_url` | Public API origin (no trailing slash, no `/api`) for the unsubscribe URL. Defaults to ENV `COMMAND_TOWER_API_BASE_URL`. Unset: headers are omitted and boot logs one warning listing the affected type keys |
| `preferences_path` | Appended to `config.application.composed_url` for the footer link. Unset: the link is `composed_url` |
| `postal_address` | Printed in the footer of promotional email. Required for any `promotional` MessageDefinition (seal check) |
| `unsubscribe_secret` | Optional. Overrides the key derived from `secret_key_base`. Never log it |

**Footer.** Three copies: transactional, promotional (adds `postal_address` and "Unsubscribe or manage email preferences"), and mandatory ("about your account"). The footer is the same in the composed and the fallback email, never carries a token, and does not change when headers are omitted.

**Headers.** `List-Unsubscribe: <{api_base_url}/messaging/unsubscribe?token=...>` and `List-Unsubscribe-Post: List-Unsubscribe=One-Click`. Set only for types that are not mandatory, are user configurable, allow `email`, and when `api_base_url` is set.

**Token.** A signed (not encrypted) `message_verifier("command_tower/messaging/unsubscribe")` value with purpose `unsubscribe`, payload `{u: user_id, t: notification_type_key}`, valid 90 days. It can only turn email off for that one user and type. `token` is a filtered parameter, so Rails logs hide it.

**Endpoint.** `POST /messaging/unsubscribe?token=` (mounted under `/api`) opts the user out of email for that type through the existing preferences update and audits `messaging_unsubscribed` (`user_history`, permanent) once; a repeat changes nothing and emits no second audit. Every failure (expired, tampered, wrong purpose, mandatory, unknown or ineligible type) returns the identical `422`, so the endpoint is not an oracle. `GET` never mutates: it returns `303` to `composed_url + preferences_path` with no token or user id, for people who click the link or scanners that prefetch it. Responses set `Cache-Control: no-store` and `Referrer-Policy: no-referrer`. Details: [api_reference.md](api_reference.md#unsubscribe).

**Limits.** Per token digest: 10 requests per 60 seconds (main limit). Per client IP: 120 per 60 seconds (high, because recipients share gateways). Over a limit: `429` with `Retry-After`. If Redis fails the limits fail open, so an outage never blocks an opt-out.

**Trusted proxy.** The client IP is `request.remote_ip`, which follows `X-Forwarded-For` only from the host's `trusted_proxies`. Hosts behind a load balancer must configure it, or every request shares one IP bucket.

**Accepted risk (O1, replay).** The token is a bearer value valid for 90 days and is not single use. Anyone holding the email can opt that user out of that type; the effect is limited to turning email off, which the user can undo in preferences.

## Host responsibilities

- Notification catalog content (registered into CommandTower notification types)
- `platform_enabled_channels` / channel policy injection
- Messaging adapter credentials (email / SMS / Pushover / Expo push) via initializer or ENV
- Host product roles that grant CT-owned Me inbox/preferences/phone/pushover/`me_push` entities (and `admin` if used)
- Product-specific operational tooling (announce rake tasks, welcome copy)

Expo push (`config.messaging.expo`): set `adapter` to `fake`, `log`, or `http` to enable the Messaging `push` channel and Me `/me/push*` (default `disabled`). `access_token` is optional — send `Authorization: Bearer` only when non-blank (required only if the Expo project enables enhanced push security). Never log the token.

Me push registration: engine `/me/push*` (collection of active endpoints). Create/replace persist via `Endpoints` and **mark_verified** in-workflow — there is no `POST /me/push/verification`. Tokens must be Expo form (`ExponentPushToken[...]` / `ExpoPushToken[...]`).

## Related

- [Controllers / routes](controllers.md)
- [API reference](api_reference.md)
- [Extending](extending.md) — Produce from host workflows; Do-Not-Extend
- [Initializing](initializing.md) — configuration and doctor
- [Pagination](pagination.md)
- [README](../README.md)
