# Authentication & Authorization Guide

Deep guide for JWT authn, session boundaries, RBAC, and how Engine vs host helpers differ.

Quick starts: [authentication.md](authentication.md), [authorization.md](authorization.md). HTTP catalog: [api_reference.md](api_reference.md). Cookies: [cookie_authentication_guide.md](cookie_authentication_guide.md).

## Authn vs authz

| Concern | Meaning | Typical failure |
|---------|---------|-----------------|
| **Authentication** | Who is calling | `401` |
| **Authorization** | Are they allowed to perform this action | `403` |

Keep them separate. Authenticate first; authorize after `current_user` is established.

## Engine HTTP boundaries

Modern engine controllers use concerns:

- `CommandTower::Auth::AuthenticationBoundary` → `authenticate_request!`
- `CommandTower::Auth::AuthorizationBoundary` → `authorize_request!`

Failures render the application **envelope** (`{ data, meta, errors }`) via `render_application_result`.

Email verification controllers call `authenticate_request!(bypass_email_validation: true)` so unverified users can complete verification.

### Host provisional helpers

`CommandTower::ApplicationController` still exposes:

```ruby
before_action :authenticate_user!
before_action :authorize_user!
```

Hosts may use these on host controllers. Failure shapes can still use older `Schema::Error::*` JSON — **not** identical to the engine envelope. Prefer aligning new host JSON APIs to the envelope yourself, or call into workflows that return `WorkflowResult`.

## Token transport

1. **Bearer** — `Authorization: Bearer <jwt>` (primary)
2. **Cookie** — optional HttpOnly JWT when `config.jwt.cookie.enabled` (see cookie guide)
3. **Signup session** — `Authorization: Signup <token>` for availability checks
4. **Password recovery session** — `Authorization: Recovery <token>` for password-reset send

Default JWT TTL: **7 days** (`config.jwt.ttl`).

### Verifier token

JWTs embed a `verifier_token` claim bound to `User#verifier_token`. Rotation invalidates outstanding tokens. See [sensitive_routes.md](sensitive_routes.md).

Authenticated password change (`PATCH /me/password`) rotates the verifier. Browser `POST /auth/logout` clears cookie transport only.

## Primary auth HTTP flows

Paths are engine-relative. Full request/response shapes: [api_reference.md](api_reference.md).

| Flow | Endpoints |
|------|-----------|
| Register | `POST /auth/register` |
| Login | `POST /auth/plain-text/login` (gate: `login.plain_text.enable?`) |
| Session | `GET /auth/session` |
| Logout | `POST /auth/logout` |
| Current account | `GET /me`, `GET /profile` |
| Principal capabilities | `GET /auth/principal-capabilities` |
| Name | `PATCH /me/name` |
| Password change | `PATCH /me/password` |
| Identity policy | `GET /auth/identity-policy` |
| Signup session | `POST /auth/signup-session` → availability GETs |
| Email verification | `POST /auth/email-verification/{send,verify}` |
| Password recovery | `POST /auth/password-recovery-session` → `POST /auth/password-reset/{send,validate,reset}` |

There is **no** `GET /user`, `POST /user/modify`, `POST /auth/login` (without `plain-text`), or `POST /auth/password/change` on the modern engine.

## Session boundaries

### Signup session

1. `POST /auth/signup-session` → `signupSessionToken`
2. Call gated availability endpoints with `Authorization: Signup …`

Used by email/username availability. Missing/invalid/expired session → `401` with `signup_session_*` codes.

### Password recovery session

1. `POST /auth/password-recovery-session` → `recoverySessionToken`
2. `POST /auth/password-reset/send` requires `Authorization: Recovery …`

Validate/reset use the emailed reset token in the body (public). See [password_reset_workflow.md](password_reset_workflow.md).

## RBAC

### Engine defaults

`lib/command_tower/authorization/default.yml`:

- **`owner`** — `entities: true` (full access). Explicit top-level authority; distinct from host operational Admin roles.

There is **no** CommandTower operational `admin` role. Admin capabilities are CT-owned **entities** (`admin_workspace`, `admin_users`, `admin_impersonation`, `admin_audit_events`, `admin_messaging_announcements`, …) that hosts grant to their own roles. Impersonation start is `admin_impersonation`; it is not included in dummy `admin` / `operations_admin`. Nested impersonation is forbidden at HTTP **418** while overlaying (workflow nested 403 if reached). Stop is a session primitive (`DELETE /auth/impersonation-session`), not an Admin Users mutation. Other Admin resource endpoints return **418** `admin_unavailable_during_impersonation` during overlay except `GET /admin/workspace` (tools disabled).

### Host RBAC file (required for Me/Auth)

`AuthorizeRequest` fails closed when the caller’s roles do not grant the CT-owned entity for the action. CommandTower ships those entity definitions. Hosts supply `config/rbac_groups.yml` with **product roles** that grant entity **names** (default path already `config/rbac_groups.yml`):

```ruby
CommandTower.configure do |c|
  c.authorization.rbac_group_path = Rails.root.join("config/rbac_groups.yml")
  c.authorization.default_membership_role = "member"
end
```

Dummy host example: `rails_app/config/rbac_groups.yml` — **`member`** grants session, me, profile, inbox, preferences, phone, pushover, email verification; operator roles grant selected Admin entities; a host-owned **`admin`** may deliberately grant a broad Admin bundle. Do not redefine `owner` or copy CT controller/entity blocks. Hosts may define an `admin` role as host policy.

Admin announcements: assign users a host role that includes `admin_messaging_announcements` (for example a host `admin` or `messaging_operator`).
### Host controller recipe

```ruby
class Host::ThingsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_user!

  def show
    # Prefer one workflow + envelope-compatible render for new APIs
  end
end
```

Map host controllers to **host-owned** RBAC entities in the host YAML. Grant CT-owned entity names to product roles; do not copy engine controller mappings.

## Engine admin HTTP

```http
GET  /admin/workspace
GET  /admin/users
GET  /admin/users/:id
POST /admin/users/:id/impersonation-sessions
GET  /admin/audit-events
POST /admin/messaging/announcements
DELETE /auth/impersonation-session
```

Impersonation is a session overlay, not a User mutation and not an Admin Workspace tool. There is no role-assign or attribute-modify admin surface.

## Email verification gate

When email verification is required, authenticated requests may receive **412** `email_verification_required` until verified. Verification endpoints bypass that gate. See [email_verification_workflow.md](email_verification_workflow.md).

## Related

- [API reference](api_reference.md)
- [Cookie authentication](cookie_authentication_guide.md)
- [Sensitive changes](sensitive_routes.md)
- [Initializing](initializing.md)
- [Messaging](messaging_integration_guide.md)
- [README](../README.md)
