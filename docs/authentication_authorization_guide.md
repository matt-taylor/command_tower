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

- **`owner`** — `entities: true` (full access)
- **`admin`** — entity `admin_messaging_announcements` on `Admin::Messaging::AnnouncementsController#create`

There are no engine default roles named `admin-read-only`, `admin-without-impersonation`, or impersonation APIs.

### Host RBAC file (required for Me/Auth)

`AuthorizeRequest` fails closed when controller actions lack entity mappings. Hosts must supply RBAC YAML (default path `config/rbac_groups.yml`):

```ruby
CommandTower.configure do |c|
  c.authorization.rbac_group_path = Rails.root.join("config/rbac_groups.yml")
end
```

Dummy host example: `rails_app/config/rbac_groups.yml` — defines a **`member`** group and entities for session, me, profile, inbox, preferences, phone, pushover, email verification. Do not redefine groups that already exist in `default.yml` (for example `admin`); add entities and attach them carefully.

Admin announcements: assign users the `admin` role (or another role that includes `admin_messaging_announcements`).

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

Map host controllers to RBAC entities the same way engine controllers are mapped in the dummy host file.

## Engine admin HTTP

Only:

```http
POST /admin/messaging/announcements
```

No SchemaHelper admin user list, attribute modify, role assign, or impersonate routes. User administration is host/ops (`command_tower:users:create`, host tooling, etc.).

## Email verification gate

When email verification is required, authenticated requests may receive **412** `email_verification_required` until verified. Verification endpoints bypass that gate. See [email_verification_workflow.md](email_verification_workflow.md).

## Related

- [API reference](api_reference.md)
- [Cookie authentication](cookie_authentication_guide.md)
- [Sensitive changes](sensitive_routes.md)
- [Initializing](initializing.md)
- [Messaging](messaging_integration_guide.md)
- [README](../README.md)
