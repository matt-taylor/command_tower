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

## Where to go next

| Need | Guide |
|------|-------|
| Full authn + RBAC design | [Authentication & authorization guide](authentication_authorization_guide.md) |
| Cookie / CORS / CSRF | [Cookie authentication](cookie_authentication_guide.md) |
| HTTP contracts | [API reference](api_reference.md) |
| Session invalidation | [Sensitive changes](sensitive_routes.md) |
| Authorization (RBAC) | [Authorization](authorization.md) |

Back to [README](../README.md).
