# Authentication

Authentication establishes **who** is calling. Failed authentication returns `401`.

## Engine controllers

Modern engine controllers use the authentication boundary:

```ruby
# via AuthenticationBoundary
before_action :authenticate_request!
```

Token extraction checks `Authorization: Bearer {token}` first, then an HttpOnly cookie when cookie auth is enabled. Failures use the application envelope (`{ data, meta, errors }`).

## Host controllers (provisional)

```ruby
before_action :authenticate_user!
# current_user is set when authentication succeeds
```

Failure JSON may still use older `Schema::Error` shapes — not identical to the engine envelope. See the deep guide.

Configure secrets and JWT options during install — see [Initializing](initializing.md).

## Impersonation (session overlay)

Impersonation is a **CommandTower session primitive**, not a User mutation. The administrator JWT stays the credential (`user_id` is always the actor). An optional `impersonation_session_id` claim locates a server-authoritative `command_tower_impersonation_sessions` row. Product identity (`current_user`, `Current.user_id`) becomes the target while the overlay is valid.

- Start: `POST /admin/users/:id/impersonation-sessions` (RBAC `admin_impersonation`)
- Stop / return-to-self: `DELETE /auth/impersonation-session` (valid administrator JWT; not `admin_impersonation` on the target)
- Timeouts: `config.impersonation.idle_timeout` (default 10 minutes) and `config.impersonation.absolute_timeout` (default 1 hour). Idle refresh is **workflow-declared** (`impersonation_activity!`); HTTP activity alone does not refresh idle.
- Concurrent independent sessions are allowed. Nested impersonation is forbidden.
- Expired overlay on a product request: `401` `impersonation_session_expired` without clearing the auth cookie.
- Admin resource endpoints other than `GET /admin/workspace` return **418** `admin_unavailable_during_impersonation` while overlaying. Workspace remains allowed and projects every tool `availability.enabled: false`.
- Target visibility for start is **only** Phase 5.4 Admin Resource Scoping (`ScopeResolution` + Admin Users Show). Unscoped hosts omit `adminScope`.

See [API reference](api_reference.md#impersonation) and [Authorization](authorization.md).

## Device sessions

Each login starts a **device session**: one row in `command_tower_device_sessions` per signed-in device. The JWT carries its `public_id` as the `sid` claim. For a token with `sid`, the row (not `jwt.ttl`) decides how long the session lives.

Table `command_tower_device_sessions`:

| Column | Purpose |
|--------|---------|
| `public_id` (string 36, unique) | The `sid` claim |
| `user_id` (FK `users`) | Owner |
| `installation_id`, `platform`, `app_version` | Optional device metadata; `installation_id` is indexed |
| `last_seen_at` | Last authenticated request (write-throttled) |
| `absolute_expires_at` | Hard end of the session |
| `revoked_at`, `revoked_reason` | Set when the session is ended or replaced |
| `legacy_generated_at` | Reserved for upgrading legacy tokens; unique with `user_id` |

Starting a session (`Services::Auth::DeviceSessions::Start`, used by `Services::Auth::IssueSession` for login) always creates a new row. If the caller supplies an `installation_id`, that user's active session on the same installation is revoked with reason `replaced`.

### Configuration

`config.session`:

| Key | Default | Meaning |
|-----|---------|---------|
| `idle_timeout` | 30 days | No authenticated request for this long expires the session |
| `absolute_timeout` | 90 days | Maximum lifetime from creation |
| `last_seen_write_interval` | 5 minutes | `last_seen_at` is written at most once per interval, so idle expiry is accurate to about this interval |
| `enforce` | `true` (ENV `COMMAND_TOWER_SESSION_ENFORCE`, `false` disables) | Kill switch. When false the revoked and idle checks are skipped; the absolute check still applies |
| `upgrade_legacy_tokens` | `true` (ENV `COMMAND_TOWER_SESSION_UPGRADE_LEGACY_TOKENS`, `false` disables) | Reserved for upgrading sid-less tokens on `GET /auth/session`. Not yet acted on |

### Session checks and 401 codes

`AuthenticateUser` looks up the row by `sid` and fails the request when:

| Condition | HTTP | Code |
|-----------|------|------|
| Row missing, belongs to another user, or revoked (with `enforce`) | 401 | `session_revoked` |
| Past `absolute_expires_at`, or idle longer than `idle_timeout` (idle with `enforce`) | 401 | `session_expired` |

These two answer with the client envelope `{ "data": null, "errors": [{ "code": "...", "message": "..." }] }` so clients can tell them from a bad token. All other 401 and 412 bodies are unchanged. The auth cookie is cleared as before.

Tokens without `sid` (issued before device sessions) keep the old rule: `generated_at + jwt.ttl`. `AuthContext#legacy_token` is true for them and `AuthContext#device_session` is nil.

A refreshed token (`GET /auth/session` with reset) keeps the same `sid`; its reported expiry is the earlier of idle expiry and absolute expiry. A cookie-sourced refresh sets the cookie only; the `X-Authorization-With-Reset` header is written only for bearer-sourced requests, at most once per response.

### Session lifecycle

| Event | Effect on device sessions |
|-------|---------------------------|
| `POST /auth/logout` | Revokes only the signing-out device (`revoked_reason: logout`). Other devices stay signed in |
| Authenticated password change, password reset, admin `verifier_token` mutation, account tombstone | Revokes **all** the user's active sessions, including the caller's (`Services::Auth::DeviceSessions::RevokeAll`; reasons `password_change`, `password_reset`, `admin_mutation`, `tombstone`). Idempotent: already-revoked rows keep their original `revoked_at` and reason |
| Login on an installation that already has a session | Old session revoked as `replaced` |
| Impersonation start / stop | The overlay and restored tokens keep the actor's `sid`, so the overlay shares the actor device's lifecycle |

Revoked sessions answer `401` `session_revoked` on the next request.

### Expiry signals

- `X-Authorization-Expire` is the **sliding** (idle) expiry: the earlier of idle expiry and absolute expiry.
- The auth cookie, when cookie auth is enabled, expires at the device session's **absolute** expiry (`absolute_expires_at`). Without a device session it uses `jwt.cookie.ttl` as before.

### Purging ended sessions

Ended rows accumulate (one per login) until purged. `CommandTower::Auth::DeviceSessions::PurgeEndedJob` (no arguments) runs `Workflows::Auth::DeviceSessions::PurgeEndedWorkflow`, which deletes sessions revoked or past `absolute_expires_at` more than 7 days ago (`retain_for`, default `7.days`). It works in batches of 1,000 ids over the indexed `revoked_at` and `absolute_expires_at` columns and writes only CommandTower-owned rows. Sessions that are only idle-expired are not purged; they reach absolute expiry and are purged then.

**The host schedules the job.** CommandTower does not schedule it. Run it daily with the host's scheduler (for example a recurring job or cron calling `CommandTower::Auth::DeviceSessions::PurgeEndedJob.perform_later`). Until it is scheduled, nothing breaks; rows only accumulate.

Host seams: `Jwt::LoginCreate.call` takes an optional `device_session:`; `Jwt::AuthenticateUser` returns `AuthenticationOutcome` with `code` and `device_session`. Hosts that wrap either must pass these through ([upgrade guide](upgrades/0.24.0.md)).

## Rate limits and soft lockout

Password login, password-reset token use, and email-verification endpoints are limited by `config.login.rate_limits`. A limit set to `0` disables that bucket. A rejected request returns `429` `auth_rate_limited` with `details.retry_after_seconds` and a `Retry-After` header. See [API reference](api_reference.md#post-authplain-textlogin).

| Bucket | Applies to | Default | Setting |
|--------|-----------|---------|---------|
| Account lockout | Failed logins per account, or per unknown identifier (same behavior for both, so it does not reveal which accounts exist) | 10 failures in 15 min | `account_failures`, `account_window_seconds` |
| Lock length | First soft lock, doubling on each repeat inside the level window, capped. Every lock expires; a failed attempt while locked never extends it | 15 min, max 60 min, levels remembered 24 h | `lock_base_seconds`, `lock_max_seconds`, `lock_level_window_seconds` |
| Login per IP | `POST /auth/plain-text/login` | 100 in 15 min | `ip_attempts`, `ip_window_seconds` |
| Reset per IP | `POST /auth/password-reset/validate` and `/reset` | 30 in 15 min | `reset_attempts_per_ip`, `reset_window_seconds` |
| Verify attempts | `POST /auth/email-verification/verify`, per user | 10 in 15 min | `verify_attempts`, `verify_window_seconds` |
| Verification send | `POST /auth/email-verification/send`, per user. A second request inside the quiet window sends nothing and answers `200` with `resendAvailableAt`; the hourly cap answers `429` | 60 s quiet, 20 per hour | `verify_send_quiet_seconds`, `verify_send_per_hour` |

A successful login clears the account's failure count and lock. A successful password reset also clears the lock. Lockout subjects are HMAC'd, so no email or username is stored in Redis in plaintext.

**Redis outage.** Limits fail open: login still works, `auth.rate_limit.fail_open` is published, and a per-process counter keeps a coarse ceiling. It is not shared across processes.

**`trusted_proxies` is required behind a load balancer.** The per-IP buckets use `request.remote_ip`, which follows `X-Forwarded-For` only from the host's `trusted_proxies`. Without it every request shares the proxy's IP and one bucket.

`login.plain_text.lockable` is a deprecated no-op; use `login.rate_limits`.

## Where to go next

| Need | Guide |
|------|-------|
| Full authn + RBAC design | [Authentication & authorization guide](authentication_authorization_guide.md) |
| Cookie / CORS / CSRF | [Cookie authentication](cookie_authentication_guide.md) |
| HTTP contracts | [API reference](api_reference.md) |
| Session invalidation | [Sensitive changes](sensitive_routes.md) |
| Authorization (RBAC) | [Authorization](authorization.md) |

Back to [README](../README.md).
