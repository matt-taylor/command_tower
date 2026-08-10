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

## Step 3 — Confirm mount path

Ensure routes include something like:

```ruby
mount CommandTower::Engine => "/"   # or "/api"
```

Engine paths below are **relative to that mount**. Route area index: [Controllers](controllers.md).

## Step 4 — Host RBAC (required)

AuthorizeRequest **fails closed**. Without host entity mappings, authenticated calls to `/me`, `/auth/session`, inbox, etc. return **403**.

The configure generator does **not** create this file.

1. Copy and adapt the dummy host file: [`rails_app/config/rbac_groups.yml`](../rails_app/config/rbac_groups.yml) → host `config/rbac_groups.yml`.
2. Keep a host group such as `member` with entities for session, me, profile, inbox, preferences, phone, pushover, email verification.
3. Do **not** redefine engine groups that already exist in `default.yml` (`owner`, `admin`).
4. Point config at the file if needed:

```ruby
CommandTower.configure do |c|
  c.authorization.rbac_group_path = Rails.root.join("config/rbac_groups.yml")
end
```

(Default path is already `config/rbac_groups.yml`.)

More: [Authorization](authorization.md), [Authentication & authorization guide](authentication_authorization_guide.md).

## Step 5 — Roles on users

RBAC YAML defines what a role **may** do. Users still need that role assigned.

- Specs and the dummy pattern use role name **`member`** for Me/Auth surfaces.
- Engine register does **not** automatically attach `member`. Hosts must assign roles via product logic, ops (`command_tower:users:create`), or host hooks after account creation.
- Admin announcements need a role that includes `admin_messaging_announcements` (engine `admin` group, or an equivalent host mapping).

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

1. `POST /auth/register` (always drawn) — create a user, then **assign `member`** (Step 5) if not done by host logic.
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
