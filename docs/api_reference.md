# CommandTower API Reference

Canonical **HTTP endpoint catalog** for the CommandTower engine. Paths are engine-relative — prefix with your host mount (for example `/api`).

Health checks are **host-owned**. The engine does not expose a health route.

Install / configure / migrate / doctor: [initializing.md](initializing.md). Extending: [extending.md](extending.md). Route area index: [controllers.md](controllers.md). Messaging emit (non-HTTP): [messaging_integration_guide.md](messaging_integration_guide.md).

Proof for contracts lives primarily under `spec/requests/command_tower/`.

## Table of Contents

1. [Shared conventions](#shared-conventions)
2. [Authentication mechanisms](#authentication-mechanisms)
3. [Auth endpoints](#auth-endpoints)
4. [Me and profile](#me-and-profile)
5. [Me Inbox](#me-inbox)
6. [Audit events](#audit-events)
7. [Preferences](#preferences)
8. [Phone](#phone)
9. [Pushover](#pushover)
10. [Admin Workspace](#admin-workspace)
11. [Impersonation](#impersonation)
12. [Admin messaging](#admin-messaging)
13. [Non-HTTP emit APIs](#non-http-emit-apis)
14. [RBAC overview](#rbac-overview)
15. [Feature gates](#feature-gates)

---

## Shared conventions

### Response envelope

Engine controllers render through `render_application_result` → `EnvelopeSerializer`.

**Success**

```json
{
  "data": {},
  "meta": {},
  "errors": []
}
```

**Failure**

```json
{
  "data": null,
  "meta": {},
  "errors": [
    { "code": "string", "message": "string", "details": {} }
  ]
}
```

- `meta` defaults to `{}` when omitted.
- Each error always has `code` and `message`. `details` appears only when present.
- Deserializer failures typically return **422** with `validation_failed` (and `details.failures` when applicable).

This envelope is the contract for **CommandTower engine HTTP** endpoints. Host product controllers may use other shapes. Provisional host helpers (`authenticate_user!` / `authorize_user!`) can still fail via older `Schema::Error` renders — see [authentication_authorization_guide.md](authentication_authorization_guide.md).

### Field casing

Response bodies use **camelCase** keys from serializers (`firstName`, `tokenExpiresAt`, `totalCount`, …).

Many deserializers accept both camelCase and snake_case aliases for inputs. Where only one form is accepted, it is noted per endpoint.

### Content type

Use `Content-Type: application/json` for JSON bodies. Responses are `application/json`.

---

## Authentication mechanisms

| Mechanism | How |
|-----------|-----|
| Bearer JWT (default) | `Authorization: Bearer <token>` |
| Cookie JWT (optional) | HttpOnly cookie when `config.jwt.cookie.enabled` — see [cookie_authentication_guide.md](cookie_authentication_guide.md) |
| Signup session | `Authorization: Signup <token>` |
| Password recovery session | `Authorization: Recovery <token>` |

**Engine controllers** use `AuthenticationBoundary` / `AuthorizationBoundary` (`authenticate_request!` / `authorize_request!`). Failures return the envelope (`401` / `403` / `412` as applicable).

**Token / cookie side effects** (login, logout, CSRF) are applied via `response_effects` on the workflow result (for example `X-Authorization-Expire`, Set-Cookie). See cookie guide for CORS and CSRF.

Default JWT TTL is **7 days** (`config.jwt.ttl`).

---

## Auth endpoints

### `POST /auth/register`

| | |
|--|--|
| **Auth** | Public |
| **Gate** | Always drawn |
| **Body** | `first_name`, `last_name`, `username`, `email`, `password`, `password_confirmation` (snake_case) |
| **Success** | **201** — `data`: `{ user, message }` where `message` is `"Account created successfully"`. No token. |
| **Errors** | `422` `validation_failed` / `email_already_registered`; `429` `signup_ip_rate_limited` |
| **Spec** | `spec/requests/command_tower/auth/register_spec.rb` |

`user` fields: `id`, `email`, `username`, `firstName`, `lastName`, `emailValidated`, `roles`.

### `POST /auth/plain-text/login`

| | |
|--|--|
| **Auth** | Public |
| **Gate** | `config.login.plain_text.enable?` (else route absent → **404**) |
| **Body** | `identifier`, `password` (snake_case) |
| **Success** | **201** — `data`: `{ user, token, tokenExpiresAt }` |
| **Errors** | `401` `invalid_credentials` |
| **Spec** | `spec/requests/command_tower/auth/plain_text/login_spec.rb` |

### `POST /auth/logout`

| | |
|--|--|
| **Auth** | Public |
| **Body** | none |
| **Success** | **200** — `data`: `{ message: "logged_out" }` (clears auth cookie when cookie mode is enabled) |
| **Spec** | `spec/requests/command_tower/auth/logout_spec.rb` |

### `GET /auth/session`

| | |
|--|--|
| **Auth** | `authenticate_request!` + `authorize_request!` |
| **Success** | **200** — `data`: `{ user, tokenExpiresAt, impersonation? }` |
| **Errors** | `401`; `403`; `412` `email_verification_required` when email verification gate applies |
| **Spec** | `spec/requests/command_tower/auth/session_spec.rb` |

`user` is the **effective** principal (target while overlaying). When an impersonation overlay is active, `impersonation` is present:

```json
{
  "active": true,
  "sessionId": "…",
  "actorUserId": 1,
  "actorDisplayName": "Ada Admin",
  "targetUserId": 42,
  "idleExpiresAt": "…",
  "absoluteExpiresAt": "…"
}
```

Omit `impersonation` when not overlaying. Clocks are ISO timestamps from the session row. Successful idle refresh may also echo `{ impersonation: { idleExpiresAt, absoluteExpiresAt } }` on that 2xx envelope **meta** only (not on generic success).

### `DELETE /auth/impersonation-session`

| | |
|--|--|
| **Auth** | `authenticate_request!` (overlay capture: expired overlays still authenticate the administrator) |
| **Success** | **200** — `data`: `{ message: "impersonation_ended" }`; `set_token` re-issues the administrator JWT **without** `impersonation_session_id` |
| **Errors** | `401`; `422` `impersonation_session_missing` |
| **Spec** | `spec/requests/command_tower/auth/impersonation_session_spec.rb` |

Does **not** authorize `admin_impersonation` on the effective user. Shared frontend persists `X-Authorization-Reset` on native 2xx responses.

### `POST /auth/signup-session`

| | |
|--|--|
| **Auth** | Public |
| **Body** | none |
| **Success** | **201** — `data`: `{ signupSessionToken, expiresAt }` (ISO8601) |
| **Errors** | `429` `signup_ip_rate_limited` |
| **Spec** | `spec/requests/command_tower/auth/signup_session_spec.rb` |

### `GET /auth/identity-policy`

| | |
|--|--|
| **Auth** | Public |
| **Success** | **200** — `data`: password / email / username / verificationCode / phoneVerificationCode policy objects (`minLength`, `maxLength`, `pattern`, …) |
| **Spec** | `spec/requests/command_tower/auth/identity_policy_spec.rb` |

### `GET /auth/principal-capabilities`

| | |
|--|--|
| **Auth** | authenticate + authorize (RBAC entity `principal_capabilities`) |
| **Success** | **200** — `data`: `{ principalCapabilities: string[] }` (unique, sorted, possessed projectable ids only) |
| **Errors** | `401`; `403`; `412` `email_verification_required` when email verification gate applies |
| **Spec** | `spec/requests/command_tower/auth/principal_capabilities_spec.rb` |

Projection is effective entity grants ∩ curated `config.registry.principal_capabilities` (never role/group names). CommandTower seeds `admin_workspace`, `admin_users`, `admin_users_update`, `admin_rbac_assignments`, `admin_audit_events`, `admin_messaging_announcements`, `admin_impersonation`, `me_audit_events`. Hosts may register additive host-owned ids. Distinct from `/me` capabilities and from `GET /admin/workspace` (tool manifest). See [Principal capabilities](principal_capabilities.md).

### `GET /auth/email/availability`

| | |
|--|--|
| **Auth** | Signup session (`Authorization: Signup …`) |
| **Gate** | `config.signup_session.email_availability?` |
| **Query** | `email` (required) |
| **Success** | **200** — `data`: `{ valid, available, message }` |
| **Errors** | `401` `signup_session_missing` / `signup_session_invalid` / `signup_session_expired`; `422`; `429` |
| **Spec** | `spec/requests/command_tower/auth/email_availability_spec.rb` |

### `GET /auth/username/availability`

| | |
|--|--|
| **Auth** | Signup session |
| **Gate** | `config.username.realtime_username_check?` |
| **Query** | `username` (required) |
| **Success** | **200** — `data`: `{ valid, available, message }` |
| **Errors** | Same signup-session family as email availability |
| **Spec** | `spec/requests/command_tower/auth/username_availability_spec.rb` |

### `POST /auth/email-verification/send`

| | |
|--|--|
| **Auth** | `authenticate_request!(bypass_email_validation: true)` + authorize |
| **Gate** | `config.login.plain_text.email_verify?` |
| **Body** | none |
| **Success** | **201** when sent / **200** when already verified — `data`: `{ message }` |
| **Errors** | `401`/`403`; `502` `verification_send_failed` |
| **Spec** | `spec/requests/command_tower/auth/email_verification_spec.rb` |

### `POST /auth/email-verification/verify`

| | |
|--|--|
| **Auth** | Same as send (bypass email validation) |
| **Gate** | Same |
| **Body** | `code` |
| **Success** | **201** `"Successfully verified email"` / **200** already verified — `data`: `{ message }` |
| **Errors** | `422` `verification_code_invalid` |
| **Spec** | `spec/requests/command_tower/auth/email_verification_spec.rb` |

Workflow detail: [email_verification_workflow.md](email_verification_workflow.md).

### `POST /auth/password-recovery-session`

| | |
|--|--|
| **Auth** | Public (always drawn; not gated by password_reset) |
| **Success** | **201** — `data`: `{ recoverySessionToken, expiresAt }` |
| **Errors** | `429` `password_recovery_ip_rate_limited` |
| **Spec** | `spec/requests/command_tower/auth/password_recovery_session_spec.rb` |

### `POST /auth/password-reset/send`

| | |
|--|--|
| **Auth** | Password recovery session (`Authorization: Recovery …`) |
| **Gate** | `config.login.plain_text.password_reset?` |
| **Body** | `email` |
| **Success** | **200** — generic message (does not reveal whether the account exists) |
| **Errors** | `401` `password_recovery_session_*`; `422`; `429`; `503` `password_reset_unavailable` |
| **Specs** | `password_reset_send_spec.rb`, `password_reset_cross_token_spec.rb` |

### `POST /auth/password-reset/validate`

| | |
|--|--|
| **Auth** | Public |
| **Gate** | `password_reset?` |
| **Body** | `token` (required); `email` optional unless config requires it |
| **Success** | **200** — `data`: `{ valid: true, expiresAt? }` |
| **Errors** | `401` `password_reset_invalid_token`; `422` |
| **Spec** | `spec/requests/command_tower/auth/password_reset_validate_and_reset_spec.rb` |

### `POST /auth/password-reset/reset`

| | |
|--|--|
| **Auth** | Public |
| **Gate** | `password_reset?` |
| **Body** | `token`, `password`, `passwordConfirmation` or `password_confirmation`; optional `email` |
| **Success** | **200** — `data`: `{ message: "Password has been successfully reset" }` |
| **Errors** | `401` `password_reset_invalid_token`; `422` |
| **Spec** | `spec/requests/command_tower/auth/password_reset_validate_and_reset_spec.rb` |

Workflow detail: [password_reset_workflow.md](password_reset_workflow.md).

---

## Me and profile

### `GET /me`

| | |
|--|--|
| **Auth** | authenticate + authorize |
| **Success** | **200** — account payload including `id`, `firstName`, `lastName`, `fullName`, `username`, `email`, `emailValidated`, `phoneNumber`, `phoneNumberValidated`, `roles`, `createdAt`, `capabilities` |
| **Spec** | `spec/requests/command_tower/me_spec.rb` |

`capabilities` keys (each `{ enabled: boolean }`): `editName`, `editUsername`, `changeEmail`, `changePassword`, `editPhone`, `editPushover`, `logoutAllDevices`, `verifyEmail`.

### `GET /profile`

| | |
|--|--|
| **Auth** | authenticate + authorize |
| **Success** | **200** — UserSerializer only (`id`, `email`, `username`, `firstName`, `lastName`, `emailValidated`, `roles`) |
| **Spec** | `spec/requests/command_tower/profile_spec.rb` |

### `PATCH /me/name`

| | |
|--|--|
| **Auth** | authenticate + authorize |
| **Body** | `firstName`/`first_name`, `lastName`/`last_name` |
| **Success** | **200** — AccountSerializer (same shape family as `GET /me`) |
| **Errors** | `422` `validation_failed` |
| **Spec** | `spec/requests/command_tower/me/name_spec.rb` |

Name-only. There is no engine HTTP for email/username self-modify or verifier rotation except via password change (and host ops).

### `PATCH /me/password`

| | |
|--|--|
| **Auth** | authenticate + authorize |
| **Body** | `currentPassword`/`current_password`, `password`, `passwordConfirmation`/`password_confirmation` |
| **Success** | **200** — `data`: `{ message: "Password updated successfully." }` |
| **Errors** | `422` validation / wrong current password |
| **Spec** | `spec/requests/command_tower/me/password_spec.rb` |

Rotates `verifier_token` (invalidates outstanding sessions). See [change_password_workflow.md](change_password_workflow.md) and [sensitive_routes.md](sensitive_routes.md).

---

## Me Inbox

All inbox routes: authenticate + authorize. Host product roles must **grant** the CT-owned `me_inbox` entity (see dummy host `rails_app/config/rbac_groups.yml`).

Pagination for list: query `limit` (default **50**, max **100**), `offset` (default **0**), `scope` (`inbox` \| `archived`, default `inbox`). List `meta`: `{ limit, offset, totalCount }`. See [pagination.md](pagination.md).

| Method | Path | Notes |
|--------|------|--------|
| `GET` | `/me/inbox` | List — `data` array of items; pagination meta |
| `GET` | `/me/inbox/:id` | Detail (+ `body`, `metadata`, `notificationTypeKey`) |
| `POST` | `/me/inbox/:id/open` | Detail |
| `PATCH` | `/me/inbox/:id/archive` | Item |
| `DELETE` | `/me/inbox/:id` | `data: null` |
| `GET` | `/me/inbox/unread-count` | `{ count }` |
| `POST` | `/me/inbox/bulk/read` | Body `ids` (1–100 ints) → `{ ids, count, changedCount }` |
| `POST` | `/me/inbox/bulk/unread` | same |
| `POST` | `/me/inbox/bulk/archive` | same |
| `POST` | `/me/inbox/bulk/restore` | same |
| `POST` | `/me/inbox/bulk/delete` | same |

**List item fields:** `id`, `title`, `status`, `read`, `viewedAt`, `createdAt`, `updatedAt`.

**Errors:** `401` / `403` / `422`; show/open may return `404` `not_found`.

**Specs:** `spec/requests/command_tower/me/inbox_spec.rb`, `me/inbox_bulk_spec.rb`.

---

## Audit events

Authenticate + authorize. Host `member` grants CT-owned `me_audit_events`. Engine `admin` grants `admin_audit_events`. Pagination matches Inbox: `limit` (default **50**, max **100**), `offset` (default **0**); list `meta`: `{ limit, offset, totalCount }`. See [pagination.md](pagination.md) and [audit.md](audit.md#reading-audit-history).

Sensitive `changes` from/to are **backend-masked** for both surfaces. Metadata is not masked. The Me controller does not accept a target-user id.

| Method | Path | Notes |
|--------|------|--------|
| `GET` | `/me/audit-events` | Caller's `user_history` rows only; optional `eventName`, `occurredAfter`, `occurredBefore`, `subjectType` |
| `GET` | `/me/audit-events/:id` | Same Me scope; **404** out of scope |
| `GET` | `/admin/audit-events` | Full ledger (unscoped) or scoped composite when scope param present; plus admin filters |
| `GET` | `/admin/audit-events/:id` | Full ledger by id; **404** missing or out of scope |

Scoped admin audit: host-scoped rows (`scope_class: host`) matching host context **OR** eligible global rows (`scope_class: global` + registry `global_visible_in_host_scope`) for in-scope affected users. **Legacy** rows excluded. Missing/malformed/unauthorized scope → **403**.

**Specs:** `spec/requests/command_tower/me/audit_events_spec.rb`, `admin/audit/events_spec.rb`, `admin/scoping/audit_events_spec.rb`.

---

## Preferences

| | Show | Update |
|--|------|--------|
| **Path** | `GET /me/preferences` | `PATCH /me/preferences/:notification_type_key` |
| **Auth** | authenticate + authorize | same |
| **Body** | none | `preferences: { inboxEnabled?, channels?: { <channelKey>: bool } }` (preference keys camelCase; unknown keys rejected) |
| **Success** | `data`: `{ categories: [...] }` | `data`: `{ notification: ... }` |
| **Errors** | `401`/`403`; update `404` unknown type; `422` invalid prefs |
| **Spec** | `spec/requests/command_tower/me/preferences_spec.rb` | |

Category / notification serializers expose catalog fields (`key`, `label`, `description`, `order`, channel availability, `preferences: { inboxEnabled, channels, storedOverridePresent }`, …).

---

## Phone

Routes are **always drawn**. Product SMS readiness is workflow-gated as **503** `sms_capability_unavailable`.

| Method | Path | Body | Success | Spec |
|--------|------|------|---------|------|
| `PATCH` | `/me/phone` | `phoneNumber`/`phone_number` | AccountSerializer | `me/phone_spec.rb` |
| `DELETE` | `/me/phone` | — | AccountSerializer | same |
| `POST` | `/me/phone/verification` | — | `{ codeLength, expiresAt, resendAvailableAt?, phoneNumber }` | `me/phone_verification_spec.rb` |
| `POST` | `/me/phone/verification/verify` | `code` (or nested `phone_verification.code`) | AccountSerializer | same |

Other errors include `422` (`phone_missing`, `phone_verification_code_invalid`, …), `429` `phone_verification_throttled` (meta may include `resendAvailableAt`), `502` `phone_verification_send_failed`.

---

## Pushover

Routes are **always drawn**. Product readiness is workflow-gated as **503** `pushover_capability_unavailable`.

| Method | Path | Body | Notes |
|--------|------|------|--------|
| `GET` | `/me/pushover` | — | Configured or unconfigured view |
| `POST` | `/me/pushover` | `userKey`/`user_key`, `applicationToken`/`application_token` | Create |
| `PATCH` / `PUT` | `/me/pushover` | same | Replace |
| `DELETE` | `/me/pushover` | — | Unconfigured view |
| `POST` | `/me/pushover/verification` | — | Verify configured credentials |

**Configured fields include:** `configured`, `id`, `channelKey`, `lifecycleState`, `verificationState`, `maskedDisplayValue`, `credentialsConfigured`, `verifiedAt`, `createdAt`, `updatedAt`, `actions: { canCreate, canVerify, canReplace, canRemove }`.

**Spec:** `spec/requests/command_tower/me/pushover_spec.rb`.

Errors include `422` (`pushover_already_configured`, `pushover_not_configured`, …), `502` `pushover_provider_unavailable`, `503`.

---

## Admin Workspace

### `GET /admin/workspace`

| | |
|--|--|
| **Auth** | authenticate + authorize (RBAC entity `admin_workspace`) |
| **Success** | **200** |
| **Spec** | `spec/requests/command_tower/admin/workspace_spec.rb` |

No query parameters. Envelope `data` (no pagination `meta`):

```json
{
  "tools": [
    {
      "id": "audit",
      "label": "Audit",
      "description": "Browse account and administrative audit history.",
      "route": "/admin/audit",
      "group": "operations",
      "sortOrder": 100,
      "icon": "history",
      "scope": { "required": true, "parameter": "partition", "label": "Partition" },
      "scopeOptions": [{ "value": "scope-a", "label": "Scope A" }],
      "availability": { "enabled": true, "reason": null }
    }
  ]
}
```

Unscoped hosts omit `scope`, `scopeOptions`, and `availability`.

Tools are filtered from the composed RBAC grant graph (`allow_everything` or an entity matching the tool's `required_entity`). `description` is additive presentation metadata (soft authoring ≤100 chars; registry hard max 160). CommandTower seeds `users`, `audit`, and `messaging`. Hosts add tools via `config.registry.admin_workspace.tool`. There is no generic tool execution route. `/me` does not duplicate this list. Do not use this endpoint as a UI permission probe — use [Principal capabilities](principal_capabilities.md).

Registration and boot rules: [Admin Workspace](admin_workspace.md).

### Admin Users

Authenticate + authorize. Host grants CT-owned `admin_users` for list/show. Identity mutations require `admin_users_update` (do not fold writes into `admin_users`). Role assignment requires `admin_rbac_assignments`. Pagination matches Inbox/Audit: `limit` (default **50**, max **100**), `offset` (default **0**); list `meta`: `{ limit, offset, totalCount }`. Free-text `search` filters email / username / first_name / last_name server-side. Safe JSON allowlist only (never password digests / verifier tokens). **No** semantic `audit(...)` on list/show (read-only inspection). Mutations emit workflow-owned `admin_direct` events. See [pagination.md](pagination.md).

When the tool declares `scope_required`, pass the configured scope query param (e.g. `partition=scope-a`). Missing/malformed/unauthorized scope → **403**. Authorized scope + user absent from narrowed relation → **404** (same as nonexistent id).

| Method | Path | Notes |
|--------|------|-------|
| `GET` | `/admin/users` | Optional `search`; optional scope param when tool is scoped; ordered by `id` DESC |
| `GET` | `/admin/users/:id` | **404** when missing or out of scope |
| `PATCH` | `/admin/users/:id/name` | `{ firstName, lastName }` — both required |
| `PATCH` | `/admin/users/:id/username` | `{ username }` |
| `PATCH` | `/admin/users/:id/email` | `{ email }`; clears `emailValidated` when the address changes |
| `PATCH` | `/admin/users/:id/email-validation` | `{ emailValidated: boolean }` — does not change email |
| `GET` | `/admin/users/assignable-roles` | Host-sourced assignable catalog (excludes `owner`) |
| `PATCH` | `/admin/users/:id/roles` | `{ roles: string[] }` — replaces assignable roles; preserves `owner` |

Success **200** `{ data, meta, errors }` where mutation `data` is the same User schema as Show. Catalog `data` is `{ roles: [{ name, description }] }`. Validation **422** `data: null`. Missing `admin_users_update` or `admin_rbac_assignments` **403**. Impersonation overlay **418**.

**Specs:** `spec/requests/command_tower/admin/users_spec.rb`, `spec/requests/command_tower/admin/users/identities_spec.rb`, `spec/requests/command_tower/admin/users/roles_spec.rb`, `spec/requests/command_tower/admin/scoping/users_spec.rb`.

Impersonation start is a separate session primitive (below), not a User mutation.

---

## Impersonation

Impersonation is a **server-authoritative session overlay** on the administrator JWT. `user_id` in the JWT is always the actor. Optional claim `impersonation_session_id` locates `command_tower_impersonation_sessions`. Expiration is row-authoritative (idle + absolute). HTTP activity alone does **not** refresh idle.

`config.impersonation.idle_timeout` default **10 minutes**; `absolute_timeout` default **1 hour**; idle must be less than absolute.

Qualifying workflows declare activity:

```ruby
class SomeWorkflow < ApplicationWorkflow
  retry_strategy :none
  impersonation_activity!
end
```

Successful `WorkflowResult` sets a request flag; `HttpBoundary` records one idle refresh after a 2xx response. Do not declare on AuthenticateRequest, Session show, principal-capabilities, workspace manifest, or Logout. 5.5 exemplars: `Profile::ShowWorkflow` (GET, yes), `Me::UpdateNameWorkflow` (PATCH, yes), `Messaging::Preferences::UpdateWorkflow` (PATCH, no).

Web cookie vs native Bearer: start/stop use `response_effects[:set_token]` (`X-Authorization-Reset` + body-adjacent header; cookie when enabled).

### `POST /admin/users/:id/impersonation-sessions`

| | |
|--|--|
| **Auth** | authenticate + authorize (`admin_impersonation`) |
| **Success** | **201** — `data`: `{ id, actorUserId, targetUserId, idleExpiresAt, absoluteExpiresAt }` |
| **Errors** | `401`; `403` (RBAC); `404` (missing / out of Users scope); `418` (overlay active); `422` self-target |
| **Spec** | `spec/requests/command_tower/admin/users/impersonation_sessions_spec.rb` |

Target lookup reuses `Services::Admin::Users::Show` with the same scope query param as Users show. Concurrent sessions are allowed. Nested start while an overlay is active is rejected at the Admin prohibition boundary (**418** `admin_unavailable_during_impersonation`); `StartWorkflow` still maps nested start to **403** `nested_impersonation_forbidden` if reached.

Admin resource endpoints other than `GET /admin/workspace` return **418** while overlaying. Workspace remains allowed and disables every tool via `availability`.

Expired product request: overlay present + invalid row → **401** `impersonation_session_expired` **without** clearing the auth cookie. Client may `DELETE /auth/impersonation-session` to return to self.

---

## Admin messaging

### `POST /admin/messaging/announcements`

| | |
|--|--|
| **Auth** | authenticate + authorize (RBAC entity `admin_messaging_announcements`) |
| **Success** | **202** |
| **Spec** | `spec/requests/command_tower/admin/messaging/announcements_spec.rb` |

**Body** (camel preferred; snake via underscore fallback): `title`, `body`, `campaignIdentity` (required), `audience` (`user_ids` \| `all_users`), `userIds` (required when `user_ids`), `notificationTypeKey` (default `"promotional_announcement"`), `executionMode` (`async` \| `sync`, default `async`), `metadata` (optional).

**Async response:** `mode`, `requested`, `campaignIdentity`, `enqueued`, `enqueueFailed`.

**Sync response:** `mode`, `requested`, `campaignIdentity`, `accepted`, `failed`, `skipped`, `failures: [{ userId, errorCode }]`.

Engine admin HTTP includes workspace manifest, announcements, audit events, Users list/show, and impersonation start. There is no role-assign or User-mutation admin surface.

---

## Non-HTTP emit APIs

Hosts call these from **product workflows** (not as HTTP on the engine):

| Service | Required kwargs |
|---------|-----------------|
| `CommandTower::Services::Messaging::Communications::Produce` | `user`, `notification_type_key`, `host_event_identity`, `title`, `body`, `platform_enabled_channels`; optional `metadata` |
| `CommandTower::Services::Messaging::Communications::ProduceMany` | `user_ids`, `notification_type_key`, `campaign_identity`, `title`, `body`, `platform_enabled_channels`; optional `metadata`, `execution_mode` (`:async` default, `:sync` capped at 25) |

Details: [messaging_integration_guide.md](messaging_integration_guide.md).

---

## RBAC overview

Engine defaults (`lib/command_tower/authorization/default.yml`):

- Group `owner` — all entities (`entities: true`)
- CT-owned Admin **entities** `admin_workspace`, `admin_users`, `admin_messaging_announcements`, `admin_audit_events` (and Me/Auth entities)
- **No** CommandTower operational `admin` role — hosts grant Admin entities deliberately

Hosts **must** supply `rbac_groups.yml` **product roles** that grant CT-owned Me / Auth / session entity names (fail-closed). Operational Admin roles are host-owned (least privilege or a deliberate broad host `admin`). The dummy host file `rails_app/config/rbac_groups.yml` shows grants-only `member` plus operator examples. Do not copy CT controller/entity definitions into the host file.

Configure via `CommandTower.configure { |c| c.authorization.rbac_group_path = ... }`. Deep guide: [authentication_authorization_guide.md](authentication_authorization_guide.md). Quick start: [authorization.md](authorization.md).

---

## Feature gates

When a gate is off, the route is **not drawn** → **404**.

| Routes | Config |
|--------|--------|
| `POST /auth/plain-text/login` | `login.plain_text.enable?` |
| `GET /auth/email/availability` | `signup_session.email_availability?` |
| `GET /auth/username/availability` | `username.realtime_username_check?` |
| Email verification send/verify | `login.plain_text.email_verify?` |
| Password reset send/validate/reset | `login.plain_text.password_reset?` |

Always drawn (not route-gated): register, logout, session, signup-session, identity-policy, principal-capabilities, password-recovery-session, Me/profile/inbox/audit-events/preferences/phone/pushover, admin workspace, admin announcements, admin audit-events. Phone/Pushover use **503** capability errors when product adapters are unavailable.

---

## Related

- [Authentication](authentication.md) / [Authorization](authorization.md)
- [Cookie authentication](cookie_authentication_guide.md)
- [Sensitive changes](sensitive_routes.md)
- [Pagination](pagination.md)
- [Messaging](messaging_integration_guide.md)
- [Admin Workspace](admin_workspace.md)
- [Principal capabilities](principal_capabilities.md)
- [README](../README.md)
