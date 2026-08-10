# Controllers and routes

CommandTower exposes platform HTTP through `CommandTower::Engine` routes. Hosts typically mount the engine (for example at `/api`) via the configure generator or a custom mount.

This page is an **index** of route areas. Detailed request/response contracts live in the [API reference](api_reference.md).

## Route areas

| Area | Prefix (engine-relative) | Purpose |
|------|--------------------------|---------|
| Auth session | `/auth/*` | Login, logout, session, register, signup-session, identity policy, availability |
| Email verification | `/auth/email-verification/*` | Send / verify email codes |
| Password recovery | `/auth/password-recovery-session`, `/auth/password-reset/*` | Forgot / reset password |
| Me / profile | `/me`, `/profile`, `/me/name`, `/me/password` | Account reads and updates |
| Inbox | `/me/inbox*` | User inbox consume (list, open, archive, bulk ops) |
| Preferences | `/me/preferences*` | Notification preferences |
| Phone | `/me/phone*` | Phone endpoint + verification |
| Pushover | `/me/pushover*` | Pushover endpoint lifecycle + verification |
| Admin messaging | `/admin/messaging/announcements` | Cohort announcements |

Exact paths depend on where the host mounts the engine.

## Controllers

Engine controllers are transport adapters: authenticate/authorize as required, deserialize, run **exactly one** workflow, render the application envelope. See [Architecture](architecture.md).

## Related

- [API reference](api_reference.md) — endpoint catalog
- [Messaging](messaging_integration_guide.md) — messaging surfaces summary
- [Extending](extending.md) — host extension boundaries
- [Initializing](initializing.md) — mount and configure
- [README](../README.md)

HTTP request specs for the engine live under `spec/requests/`.
