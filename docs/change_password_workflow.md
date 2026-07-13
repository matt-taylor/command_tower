# Authenticated Password Change Workflow

## Overview

Authenticated password change lets a signed-in user replace their password by proving knowledge of the current password. On success, CommandTower rotates `verifier_token` in the same database transaction as the password digest update, invalidating **all** existing JWT sessions (including the caller’s). The API does **not** re-issue a JWT; hosts must clear local auth and send the user through Sign In again.

This is distinct from [password recovery](password_reset_workflow.md) (`POST /auth/password/forgot/*`), which is public and token-based and does **not** rotate the verifier today.

## Endpoint

| Item | Value |
|------|--------|
| Route | `POST /auth/password/change` |
| Auth | JWT required (`authenticate_user!`) |
| Controller | `CommandTower::Auth::PlainTextController#password_change_post` |
| Service | `CommandTower::LoginStrategy::PlainText::ChangePassword` |
| Feature gate | `CommandTower.config.login.plain_text.enable?` (not gated by `password_reset?`) |

### Why this controller

Password change lives on `Auth::PlainTextController` next to other plain-text auth flows (login, create, email verify, forgot/reset). Selective `before_action :authenticate_user!` mirrors email-verify’s selective JWT pattern, while keeping the route under `/auth/password/*`. Account attribute edits remain on `UserController` (`/user/modify`).

## Request

```json
{
  "current_password": "string",
  "password": "string",
  "password_confirmation": "string"
}
```

## Success response (200)

```json
{
  "message": "Password has been successfully changed"
}
```

No JWT, no verifier, and no password material are returned.

## Service flow

1. Authenticate `current_password` via `user.authenticate`
2. Confirm `password` matches `password_confirmation`
3. Enforce `password_length_min` / `password_length_max` from plain_text config
4. In one DB transaction: save new password → `reset_verifier_token!`
5. On txn failure: roll back both ops; surface typed CT failures (`invalid_arguments` for validation/persist errors, `status: 500` for verifier infrastructure failure)
6. Set minimal success message only

## Failures (HTTP)

| Condition | Status | Shape |
|-----------|--------|--------|
| Missing / invalid JWT | 401 | Existing unauthenticated shared behavior |
| Bad current password, confirmation, length, model errors | 400 | `InvalidArguments` schema (same pattern as `/user/modify` and forgot reset) |
| Verifier rotation / unexpected infra failure | 500 | `Schema::Error::Base` |

## Contrast with recovery reset

| | Authenticated change | Forgot / reset |
|--|----------------------|----------------|
| Proof | Current password | UserSecret token |
| Route | `POST /auth/password/change` | `POST /auth/password/forgot/reset` |
| Auth | JWT | Public |
| Verifier | Rotated (required) | Not rotated (known gap) |
| Post-success session | All JWTs invalid; host → Sign In | Host-defined |

## Security notes

- Never log passwords, verifier values, or raw request bodies containing secrets.
- Success deliberately does **not** preserve the current session.
- Hosts must treat success as a forced re-login.
