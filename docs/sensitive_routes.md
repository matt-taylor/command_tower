# Sensitive changes and session invalidation

CommandTower JWTs are bound to the authenticated user’s **verifier token**. When the verifier rotates, previously issued access tokens that carried the old verifier no longer authenticate (`401`).

This is the platform mechanism behind “logout everywhere” and post-password-change session invalidation.

## Verifier token on `User`

Each `User` may store:

- `verifier_token` — opaque string embedded in JWTs at issue time
- `verifier_token_last_reset` — timestamp of the last rotation

API:

```ruby
user.reset_verifier_token!    # generates a new token, updates timestamp, returns the value
user.retreive_verifier_token! # returns existing token or creates one (historical spelling)
```

Authentication compares the verifier claim in the JWT to the user’s current `verifier_token`. A mismatch fails authentication.

## When the platform rotates the verifier

| Event | Behavior |
|-------|----------|
| Authenticated password change (`PATCH /me/password`) | Rotates verifier so prior tokens fail |
| Host / ops call `user.reset_verifier_token!` | Explicit revoke-all-sessions |

There is no engine HTTP admin “mutate user with `verifier_token: true`” route. `UserAttributes::Mutate` may still exist for internal/host use; do not assume a public SchemaHelper admin path.

Browser `POST /auth/logout` clears cookie/session transport for that client; it does **not** by itself rotate `verifier_token` for all devices. Use verifier rotation when all outstanding JWTs must die.

## Host guidance

- Treat password changes and explicit “revoke all sessions” as **sensitive** operations that should rotate the verifier.
- Do not expose `verifier_token` in API payloads (platform serializers omit it).
- Prefer platform workflows/services for password change rather than hand-editing password digests without rotation.
- `UserSecret` backs related validation/recovery secrets; see [Models](models.md).

## Related

- [Change password workflow](change_password_workflow.md)
- [Authentication](authentication.md) / [Authentication & authorization guide](authentication_authorization_guide.md)
- [Cookie authentication](cookie_authentication_guide.md)
- [Models](models.md)
- [README](../README.md)
