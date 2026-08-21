# Messaging with CommandTower

CommandTower owns modern messaging **platform** surfaces. Hosts supply product content, channel policy, and adapter credentials.

Complete install and host RBAC first: [Host integration](host_integration_guide.md) (Steps 1–8 before emitting or wiring phone/Pushover).

## Current surfaces

| Concern | Path / entry |
|---------|----------------|
| User inbox (consume) | Engine `/me/inbox*` — see [API reference](api_reference.md#me-inbox) |
| Preferences | Engine `/me/preferences*` — see [API reference](api_reference.md#preferences) |
| Phone / Pushover endpoints | Engine `/me/phone*`, `/me/pushover*` (503 when capability unavailable) |
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
- Messaging adapter credentials (email / SMS / Pushover) via initializer or ENV
- Host product roles that grant CT-owned Me inbox/preferences/phone/pushover entities (and `admin` if used)
- Product-specific operational tooling (announce rake tasks, welcome copy)

## Related

- [Controllers / routes](controllers.md)
- [API reference](api_reference.md)
- [Extending](extending.md) — Produce from host workflows; Do-Not-Extend
- [Initializing](initializing.md) — configuration and doctor
- [Pagination](pagination.md)
- [README](../README.md)
