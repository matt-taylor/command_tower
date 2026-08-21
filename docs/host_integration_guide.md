# Host Integration Guide

**Start here** for integrating CommandTower into a new Rails host.

This page owns the **order of operations**. It does not replace specialty docs: install details stay in [Initializing](initializing.md), HTTP contracts in [API reference](api_reference.md), boundaries in [Extending](extending.md).

`command_tower:doctor` green means secrets/migrations look sane. It does **not** prove Me/Auth authorization works.

## Prerequisites

- A Rails host application (engine is mounted into the host)
- `gem "command_tower"` in the host Gemfile (path, git, or released gem)
- Host-owned database (and any host Redis/job stack your app already uses)

## Step 1 — Install

Follow [Initializing](initializing.md):

```bash
bundle install
bin/rails command_tower:install
bin/rails db:migrate
bin/rails command_tower:doctor
```

That copies CT migrations, generates `config/initializers/command_tower.rb` (unless skipped), and mounts `CommandTower::Engine` (unless skipped).

## Step 2 — Secrets and initializer

In the host initializer, set at least:

- `config.jwt.hmac_secret`
- `config.signup_session.jwt_secret` (or `SIGNUP_SESSION_JWT_SECRET`)
- `config.password_recovery_session.jwt_secret` (or `PASSWORD_RECOVERY_SESSION_JWT_SECRET`)

Re-run `bin/rails command_tower:doctor`. Details: [Initializing — Configuration](initializing.md#configuration).

Dummy-host reference: [`rails_app/config/initializers/command_tower.rb`](../rails_app/config/initializers/command_tower.rb).

### Email / SMTP

CommandTower owns ActionMailer delivery for engine mailers (email verification, password reset, messaging channel mail).

| Environment | Delivery |
|-------------|----------|
| `test` | `:test` (in-memory `ActionMailer::Base.deliveries`; no external SMTP) |
| development / production | `:smtp` unless the host explicitly sets `config.email.delivery_method` |

Non-secret knobs live on `config.email.*` (defaults: `smtp.gmail.com`, port `587`, `plain`, STARTTLS auto). Secrets come from Credential Resolution:

- `config.credentials.smtp.user_name` / `password`, or
- ENV `GMAIL_USER_NAME` / `GMAIL_PASSWORD`

`SmtpActionMailerBridge` merges resolved credentials into `action_mailer.smtp_settings` at the end of `CommandTower.configure`. Missing credentials fail at send when `raise_delivery_errors` is true. `From` uses the resolved SMTP username when present.

Doctor does **not** probe SMTP connectivity.

## Step 3 — Confirm mount path

Ensure routes include something like:

```ruby
mount CommandTower::Engine => "/"   # or "/api"
```

Engine paths below are **relative to that mount**. Route area index: [Controllers](controllers.md).

## Step 3b — Inherit execution-boundary bases

Greenfield hosts should inherit CommandTower bases so Execution Context is established automatically:

```ruby
class ApplicationController < CommandTower::ApplicationController
end

class ApplicationJob < CommandTower::ApplicationJob
end
```

Unauthenticated host endpoints (for example health checks) still receive HTTP `execution_uuid` / `correlation_id`. Successful authentication enriches the **same** context with `user_id` / `effective_user_id`.

Workflows and services consume `CommandTower::Current` (or `execution_context`); they do not establish a new execution. For Rake/console, use `CommandTower.with_execution(source: :rake) { ... }`.

`Auth::RequestContext` is JWT request/response transport, not Execution Context. Details: [Extending — Execution Context](extending.md#execution-context).

Lifecycle and semantic events: [Eventing](eventing.md).

If superclass inheritance is technically blocked, include `CommandTower::Execution::HttpBoundary` / `JobBoundary` on the host bases. That is an escape hatch, not the preferred contract.

## Step 4 — Host RBAC (required)

AuthorizeRequest **fails closed**. CommandTower ships **CT-owned** entity definitions (Me, session, inbox, Admin Workspace capabilities, …) and the platform full-access role (`owner`) in `lib/command_tower/authorization/default.yml`. CommandTower does **not** ship an operational `admin` role.

The host YAML (default `config/rbac_groups.yml`) is a **second source**. Composition is additive. Hosts:

1. Define product roles (typically `member`).
2. **Grant names** of already-defined CT entities to those roles.
3. Optionally define **host-owned** entities for **host** controllers.
4. Deliberately compose operational Admin roles (least privilege or a broad host-owned `admin`).

Do **not** copy CommandTower controller/entity blocks into the host file. Do **not** redefine `owner` or CT entity names. A host **may** define an `admin` group as host policy. Conflicts fail at boot (no last-write-wins).

Dummy host grants-only example: [`rails_app/config/rbac_groups.yml`](../rails_app/config/rbac_groups.yml).

```ruby
CommandTower.configure do |c|
  c.authorization.rbac_group_path = Rails.root.join("config/rbac_groups.yml")
  c.authorization.default_membership_role = "member" # optional; nil disables
end
```

`default_membership_role` is validated against the **composed** graph at boot. Unknown names fail configuration finalization.

More: [Authorization](authorization.md), [Authentication & authorization guide](authentication_authorization_guide.md).

Product audit names (later) register additively:

```ruby
CommandTower.configure do |c|
  c.registry.audit.event :wager_placed do |event|
    event.allowed_changes = %i[status]
    event.user_history = true
  end
end
```

Do **not** redefine CommandTower-owned audit names. Audit rows persist in CommandTower after `command_tower:install:migrations` and `db:migrate`. See [Audit](audit.md).

Admin Workspace tools register additively (navigation metadata, not a dispatcher):

```ruby
CommandTower.configure do |c|
  c.registry.admin_workspace.tool :host_example do |tool|
    tool.label = "Example"
    tool.description = "Short launcher explanation of what this tool does."
    tool.route = "/admin/example"
    tool.group = :product
    tool.sort_order = 300
    tool.required_entity = :host_example_entity
  end
end
```

Do **not** redefine CommandTower-owned tool ids (`users`, `audit`, `messaging`). Hosts own copy for host tools (`description` soft ≤100 / hard ≤160). Manifest: [Admin Workspace](admin_workspace.md).

Principal capabilities register additively (frontend-projectable ids, not a dump of all entities):

```ruby
CommandTower.configure do |c|
  c.registry.principal_capabilities.capability :host_example do |capability|
    capability.required_entity = :host_example_entity
  end
end
```

Do **not** redefine CommandTower-owned capability ids (`admin_workspace`, `admin_users`, `admin_impersonation`, `admin_audit_events`, `admin_messaging_announcements`). Projection: [Principal capabilities](principal_capabilities.md). Grant `admin_impersonation` only to roles that should start impersonation of visible users. Dummy `admin` does not include it.

## Step 5 — Roles on users

RBAC YAML defines what a role **may** do. Users still need that role assigned.

- Specs and the dummy pattern use role name **`member`** for Me/Auth surfaces (including entity `principal_capabilities`).
- When `authorization.default_membership_role` is set (for example `"member"`), register assigns that role **in the same transaction** as user create. Failure rolls back the user.
- When it is `nil`, register does not attach roles. Hosts may assign via product logic, ops (`command_tower:users:create`), or other host workflows.
- Installing CommandTower does **not** grant operational Admin access. Hosts must deliberately grant Admin entities.
- Admin announcements need a host role that includes `admin_messaging_announcements`.
- Admin Workspace manifest needs a host role that includes `admin_workspace`. Tool visibility still depends on each tool's `required_entity`.
- `GET /auth/principal-capabilities` needs entity `principal_capabilities` on the caller’s roles (grant on `member` like session/me). Possessed Admin projectables still depend on the Admin entity grants above.
- A host may define a broad `admin` role that grants many Admin entities — that is host policy, not a CommandTower default.
## Step 6 — Enable feature gates you need

When a gate is off, the route is **not drawn** → **404**.

| Capability | Config |
|------------|--------|
| Plain-text login | `config.login.plain_text.enable = true` |
| Email verification routes | `config.login.plain_text.email_verify = true` |
| Password reset routes | `config.login.plain_text.password_reset = true` |
| Email availability | `config.signup_session.email_availability = true` |
| Username availability | `config.username.realtime_username_check = true` |

Full gate list: [API reference — Feature gates](api_reference.md#feature-gates).

## Step 7 — Choose auth client path

- **API / mobile:** `Authorization: Bearer <jwt>` (default)
- **Browser / SPA cookies:** enable `config.jwt.cookie` (+ CSRF as needed) — [Cookie authentication](cookie_authentication_guide.md)

Engine HTTP success/error bodies use the application envelope `{ data, meta, errors }`. Host provisional helpers (`authenticate_user!`) can differ — [Authentication](authentication.md).

## Step 8 — Smoke check

With gates and RBAC in place (paths relative to your mount):

1. `POST /auth/register` (always drawn) — with `default_membership_role` configured, the user is created **and** assigned that role in one transaction.
2. `POST /auth/plain-text/login` (if enabled) — receive `data.token`.
3. `GET /me` with Bearer token — expect **200** and envelope `data` (account payload).

If you get **401**, authn failed. If you get **403**, fix Steps 4–5 before debugging clients.

Contracts: [API reference](api_reference.md).

## Step 9 — Messaging (when needed)

Host owns:

- Notification catalog / types
- `platform_enabled_channels` / channel policy
- Adapter credentials (email / SMS / Pushover)

Emit from a **host product workflow** via `Communications::Produce` / `ProduceMany` — not by bypassing workflows. See [Messaging](messaging_integration_guide.md) and [Extending](extending.md).

Phone/Pushover routes are always drawn; missing product readiness returns **503** capability errors.

## Step 10 — Host tests

```ruby
require "command_tower/testing"
CommandTower::Testing.install!
```

Details: [Testing](testing.md). Prefer `spec/requests/` patterns in the gem as HTTP contract proof.

## Done when

- Doctor passes for secrets/migrations
- Host `rbac_groups.yml` maps Me/Auth entities
- Users who should use Me surfaces have the host `member` (or equivalent) role
- Needed feature gates are enabled
- `GET /me` returns **200** with a Bearer token for a member user

## Common failures

| Symptom | Likely cause |
|---------|----------------|
| Doctor green, `GET /me` is **403** | Missing host RBAC YAML or user lacks `member` (Steps 4–5) |
| `POST /auth/plain-text/login` is **404** | `login.plain_text.enable?` off (Step 6) |
| Password-reset / availability **404** | Matching feature gate off |
| Phone / Pushover **503** | Capability / adapters not ready (Step 9) |
| Confused error JSON on host controllers | Provisional `authenticate_user!` vs engine envelope (Step 7) |

## Related

- [Initializing](initializing.md)
- [Extending](extending.md)
- [API reference](api_reference.md)
- [Authentication & authorization guide](authentication_authorization_guide.md)
- [Messaging](messaging_integration_guide.md)
- [README](../README.md)
