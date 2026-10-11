# 09 — RBAC

## Purpose

Give authenticated users a **product role** that **grants CommandTower entity names**. Without this, login can succeed and `GET /me` returns **403**.

## Prerequisites

- [`08-initializer.md`](08-initializer.md)

## Files the host creates

`config/rbac_groups.yml` — host-owned composition.

CommandTower ships **entity definitions** in `lib/command_tower/authorization/default.yml` (inside the gem). Hosts **grant those names**. Hosts may add host-owned entities for host controllers.

In-engine dummy for **shape**: [`../../rails_app/config/rbac_groups.yml`](../../rails_app/config/rbac_groups.yml). Use it to see a `member` grant list and that Admin bundles are **host policy**. Do not copy dummy-only entities (`dummy_admin_example`) into a product host.

Contract: [`../authorization.md`](../authorization.md), [`../authentication_authorization_guide.md`](../authentication_authorization_guide.md).

## Procedure

### 1. Author `member` (minimum for Me)

Grant the Me/Auth entity names your smoke path needs. A typical starting `member` (from the dummy, minus product-specific extras you do not want yet):

```yaml
groups:
  member:
    description: Standard authenticated application user
    entities:
      - email_verification_send
      - email_verification_verify
      - session
      - me
      - profile
      - me_name
      - me_password
      - me_account
      - me_inbox
      - me_audit_events
      - me_preferences
      - me_phone
      - me_phone_verification_send
      - me_phone_verification_verify
      - me_pushover
      - me_pushover_verification
      - me_push
      - me_experience_states
      - principal_capabilities
```

Trim unused Me surfaces if you want a thinner first grant (you **must** keep `me` and `session` for the smoke in [`12-smoke-check.md`](12-smoke-check.md)). Missing `me` → **403** on `GET /me`.

### 2. `default_membership_role`

In `config/initializers/command_tower.rb`:

```ruby
config.authorization.default_membership_role = "member"
```

New users then receive `member` without a manual assign. If you omit this, you must assign roles some other supported way before Me works.

### 3. Admin roles (not required to finish bootstrap)

Do **not** auto-grant new Admin capabilities to a generic Admin role. CommandTower does not ship an accumulating operational `admin` role. `owner` (`entities: true`) is full-access and distinct from host Admin bundles.

If you add Admin later, copy the **pattern** from the dummy (`audit_operator`, `operations_admin`, …): explicit entity lists on a host role. See [`../admin_workspace.md`](../admin_workspace.md).

The frontend workspace and user detail call these entities. Grant each one the role should have:

- `admin_workspace`
- `admin_users`
- `admin_audit_events`
- `admin_messaging_announcements`
- `admin_impersonation`

`admin_impersonation` is what shows Impersonate. The frontend does not add a route for it.

## Stop

`config/rbac_groups.yml` exists with a `member` group that grants `me` (and the rest you need). `default_membership_role` is `"member"` (or you have a documented assign path). Next: [`10-roles-and-gates.md`](10-roles-and-gates.md).
