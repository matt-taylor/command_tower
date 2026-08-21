# Controllers and routes

CommandTower exposes platform HTTP through `CommandTower::Engine` routes. Hosts typically mount the engine (for example at `/api`) via the configure generator or a custom mount.

This page is an **index** of route areas. Detailed request/response contracts live in the [API reference](api_reference.md).

## Route areas

| Area | Prefix (engine-relative) | Purpose |
|------|--------------------------|---------|
| Auth session | `/auth/*` | Login, logout, session, register, signup-session, identity policy, principal-capabilities, availability |
| Email verification | `/auth/email-verification/*` | Send / verify email codes |
| Password recovery | `/auth/password-recovery-session`, `/auth/password-reset/*` | Forgot / reset password |
| Me / profile | `/me`, `/profile`, `/me/name`, `/me/password` | Account reads and updates |
| Inbox | `/me/inbox*` | User inbox consume (list, open, archive, bulk ops) |
| Audit events | `/me/audit-events`, `/admin/audit-events` | User and admin audit history reads (masked) |
| Admin Users | `/admin/users` | Read-only Admin user list/show |
| Impersonation | `/admin/users/:id/impersonation-sessions`, `/auth/impersonation-session` | Start overlay; stop / return-to-self |
| Admin Workspace | `/admin/workspace` | RBAC-filtered admin tool manifest |
| Preferences | `/me/preferences*` | Notification preferences |
| Phone | `/me/phone*` | Phone endpoint + verification |
| Pushover | `/me/pushover*` | Pushover endpoint lifecycle + verification |
| Admin messaging | `/admin/messaging/announcements` | Cohort announcements |

Exact paths depend on where the host mounts the engine.

## Controllers

Engine controllers are transport adapters: authenticate/authorize as required, deserialize, run **exactly one** workflow, render the application envelope. See [Architecture](architecture.md).

## Related

- [API reference](api_reference.md) — endpoint catalog
- [Principal capabilities](principal_capabilities.md) — FE-projectable possession projection
- [Admin Workspace](admin_workspace.md) — registry and manifest
- [Messaging](messaging_integration_guide.md) — messaging surfaces summary
- [Extending](extending.md) — host extension boundaries
- [Initializing](initializing.md) — mount and configure
- [README](../README.md)

HTTP request specs for the engine live under `spec/requests/`.
