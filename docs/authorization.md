# Authorization (RBAC)

Authorization establishes **permission** after authentication. Failed authorization returns `403`.

Host `rbac_groups.yml` is a **required integration step** (Step 4) — see [Host integration](host_integration_guide.md#step-4--host-rbac-required). CommandTower ships CT-owned entity definitions. Hosts grant those names to product roles; they must not copy CT controller mappings. Without a host role that grants Me/Auth entities, authenticated calls return **403**.

## Quick usage (host provisional)

```ruby
# Order matters: authorize depends on current_user from authentication
before_action :authenticate_user!
before_action :authorize_user!
```

Engine controllers use `authorize_request!` instead (AuthorizationBoundary) and return the application envelope on failure.

## Capability ownership vs role composition

**Platform owns capabilities.** CommandTower defines RBAC entities (Me/Auth surfaces and Admin capabilities such as `admin_workspace`, `admin_users`, `admin_impersonation`, `admin_audit_events`, `admin_messaging_announcements`).

**Hosts own privilege bundles.** Operational/admin roles are host-defined groups that grant selected CT entities (and optional host entities). Installing CommandTower does **not** automatically grant operational Admin access.

## Roles and host mapping

Engine defaults in `lib/command_tower/authorization/default.yml`:

- `owner` — explicit full access (`entities: true`). Distinct from host-defined operational Admin roles.
- CT-owned **entities** for Me, session, profile, inbox, preferences, phone, Pushover, email verification, admin announcements, admin audit events, Admin Users, impersonation start, and the Admin Workspace manifest
- **No** CommandTower operational `admin` role. New Admin entities require explicit host grants and must not accumulate into a platform Admin bundle.

Hosts grant `admin_impersonation` explicitly. Dummy `admin` / `operations_admin` do **not** include it; `impersonation_operator` does. `owner` keeps `entities: true`.

Stop / return-to-self (`DELETE /auth/impersonation-session`) is a session primitive: it authenticates the administrator JWT and does not authorize `admin_impersonation` on the effective (target) user.

While overlaying, Admin resource endpoints other than `GET /admin/workspace` return **418** `admin_unavailable_during_impersonation`. Workspace remains allowed so the operator can see disabled tiles. Impersonation start consumes Admin Resource Scoping as the sole target-visibility contract.

Hosts define product roles (for example `member`, `audit_operator`, or a deliberate host-owned `admin`) that **grant entity names**. See dummy host `rails_app/config/rbac_groups.yml`. Do not redefine `owner` or CT **entity** identifiers. A host may define a broad `admin` role as **host policy**; that is allowed. Composition is additive; conflicts fail at boot.

Optional: `config.authorization.default_membership_role = "member"` assigns that composed role atomically on register.

## Principal capabilities (FE projection)

`GET /auth/principal-capabilities` returns possessed **frontend-projectable** ids from effective entity grants ∩ `config.registry.principal_capabilities`. Groups compose privilege; they are never the FE gating contract. See [Principal capabilities](principal_capabilities.md).

## Where to go next

| Need | Guide |
|------|-------|
| Full RBAC entities, roles, failure shapes | [Authentication & authorization guide](authentication_authorization_guide.md) |
| Frontend-projectable capability ids | [Principal capabilities](principal_capabilities.md) |
| Admin Workspace least privilege | [Admin Workspace](admin_workspace.md) |
| Authentication | [Authentication](authentication.md) |
| Install / config | [Initializing](initializing.md) |

Back to [README](../README.md).
