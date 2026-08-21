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

## Where to go next

| Need | Guide |
|------|-------|
| Full authn + RBAC design | [Authentication & authorization guide](authentication_authorization_guide.md) |
| Cookie / CORS / CSRF | [Cookie authentication](cookie_authentication_guide.md) |
| HTTP contracts | [API reference](api_reference.md) |
| Session invalidation | [Sensitive changes](sensitive_routes.md) |
| Authorization (RBAC) | [Authorization](authorization.md) |

Back to [README](../README.md).
