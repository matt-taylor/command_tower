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
