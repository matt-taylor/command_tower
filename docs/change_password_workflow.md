# Authenticated Password Change Workflow

Authenticated password change lets a signed-in user replace their password by proving knowledge of the current password. On success, CommandTower rotates `verifier_token` in the same transaction as the password digest update, invalidating **all** existing JWT sessions (including the caller’s) and ending every device session (see [Authentication](authentication.md#session-lifecycle)); old tokens then answer `401` `session_revoked`. The API does **not** re-issue a JWT; hosts must clear local auth and send the user through Sign In again.

This is distinct from [password recovery](password_reset_workflow.md), which is public and recovery-session/token-based.

## Purpose and orchestration

| Item | Value |
|------|--------|
| Route | `PATCH /me/password` (engine-relative) |
| Auth | Authentication + authorization boundaries |
| Controller | `CommandTower::Me::PasswordController#update` |
| Workflow | `CommandTower::Workflows::Me::ChangePasswordWorkflow` (`ApplicationWorkflow`, `retry_strategy :none`) |
| Service | `CommandTower::Services::Me::ChangePassword` |
| Deserializer | `CommandTower::Deserializers::Me::ChangePasswordDeserializer` |
| Serializer | `CommandTower::Serializers::Me::ChangePasswordResponseSerializer` |
| Feature gate | Route always drawn (not constrained in `routes.rb`) |

**Boundary:** The controller deserializes input and runs **one** workflow. The workflow orchestrates the change-password service and maps failures to HTTP status. It does not implement password rules itself.

## Request

```json
{
  "current_password": "string",
  "password": "string",
  "password_confirmation": "string (optional)"
}
```

`password_confirmation` (or `passwordConfirmation`) is optional. When sent and different from `password` the request fails; when absent no comparison is made.

## Success (200)

Serialized success payload (message only). Response effects include `clear_token: true` so cookie/header sessions are cleared. No JWT, verifier, or password material is returned.

## Service flow (under the workflow)

1. Authenticate `current_password`
2. If `password_confirmation` was sent, confirm it matches `password`
3. Enforce configured password length bounds
4. In one DB transaction: persist new password digest → `reset_verifier_token!` → revoke all device sessions (`RevokeAll`, reason `password_change`), including the caller's
5. On failure: typed application errors → workflow HTTP mapping

## Failures

| Condition | Typical status |
|-----------|----------------|
| Missing / invalid JWT | 401 |
| Validation / bad current password / confirmation | 4xx via Me error mapping |
| Unexpected infra failure | 5xx |

## Contrast with recovery reset

| | Authenticated change | Forgot / reset |
|--|----------------------|----------------|
| Proof | Current password | Recovery session + reset token |
| Route | `PATCH /me/password` | `POST /auth/password-recovery-session` + `/auth/password-reset/*` |
| Auth | JWT | Public (+ recovery session) |
| Verifier | Rotated | See recovery guide |
| Post-success | All JWTs invalid; host → Sign In | Host-defined |

## Related

- [Sensitive changes](sensitive_routes.md)
- [API reference](api_reference.md)
- [Password reset workflow](password_reset_workflow.md)
- [Extending](extending.md)
