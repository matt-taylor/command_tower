# Messaging with CommandTower

CommandTower owns modern messaging **platform** surfaces. Hosts supply product content, channel policy, and adapter credentials.

Complete install and host RBAC first: [Host integration](host_integration_guide.md) (Steps 1–8 before emitting or wiring phone/Pushover).

## Current surfaces

| Concern | Path / entry |
|---------|----------------|
| User inbox (consume) | Engine `/me/inbox*` — see [API reference](api_reference.md#me-inbox) |
| Preferences | Engine `/me/preferences*` — see [API reference](api_reference.md#preferences) |
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

## ProduceMany (multi recipient)

| Kwarg | Required / notes |
|-------|------------------|
| `user_ids` | yes (`Array` of integer ids) |
| `notification_type_key` | yes |
| `campaign_identity` | yes — fan-out builds `host_event_identity` as `"#{campaign_identity}/#{user.id}"` |
| `title`, `body` | yes |
| `platform_enabled_channels` | yes |
| `metadata` | optional |
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

### Inbox document override (`inbox_document.json.erb`)

The Me Inbox detail `content` field (`inbox_document_v1`, see [api_reference.md](api_reference.md#me-inbox)) is built by a separate collaborator, `InboxDocumentRenderer`, using the **same** type-directory convention and sanitized-key rule as above, resolved through `TemplateResolver.render_type_template`:

```text
app/views/command_tower/messaging/rendering/
  <notification_type_key>/
    inbox_document.json.erb   # optional type-specific inbox content override
```

This override has **no generic ERB fallback file** — the generic Inbox document is built in pure Ruby from `communication.body`/`metadata`, not from a template. Because of that, the fail-open contract here is stricter than `ChannelRenderer`'s: a missing type template, malformed JSON, an envelope with the wrong `schema` or a non-Array `blocks`, or a template that raises mid-render all fall back silently to the generic document — the Inbox read path never surfaces a `RenderError` and never 500s. A valid envelope with one invalid/unknown block strips only that block, keeping the rest; if stripping empties `blocks`, the generic document is used instead.

## Me Inbox HTTP (summary)

| Concern | Contract |
|---------|----------|
| List | `GET /me/inbox?limit=&offset=&scope=` — meta `{ limit, offset, totalCount }` |
| Detail / open / archive / delete | `/me/inbox/:id` (+ `open`, `archive`) |
| Bulk | `POST /me/inbox/bulk/{read,unread,archive,restore,delete}` with body `ids` |
| Unread | `GET /me/inbox/unread-count` |

Pagination detail: [pagination.md](pagination.md). Full catalog: [api_reference.md](api_reference.md#me-inbox).

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
