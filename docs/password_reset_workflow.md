# Password Reset (Forgot Password) Workflow

Public password recovery for users who cannot authenticate. Flow uses a **password-recovery session** plus gated **password-reset** endpoints. Detailed schemas live here and are summarized in the [API reference](api_reference.md).

## Purpose and orchestration

| Step | Route | Workflow |
|------|-------|----------|
| Create recovery session | `POST /auth/password-recovery-session` | `Workflows::Auth::PasswordRecoverySession::CreateWorkflow` |
| Send reset email | `POST /auth/password-reset/send` | `Workflows::Auth::PasswordReset::SendWorkflow` |
| Validate token | `POST /auth/password-reset/validate` | `Workflows::Auth::PasswordReset::ValidateWorkflow` |
| Reset password | `POST /auth/password-reset/reset` | `Workflows::Auth::PasswordReset::ResetWorkflow` |

All listed workflows inherit `ApplicationWorkflow` with `retry_strategy :none`. Controllers under `CommandTower::Auth::PasswordReset::*` and password-recovery-session authenticate the recovery session where required, deserialize, run **one** workflow, and render `WorkflowResult`.

**Feature gate:** `CommandTower.config.login.plain_text.password_reset?` (reset endpoints). Recovery session creation is part of the public recovery path.

**Boundary:** Controllers own transport + recovery-session auth. Workflows orchestrate rate limits and password-reset services. Services own email/token capability details. Do not call messaging execution internals from hosts — see [extending.md](extending.md).

## High-level characteristics

- **No user JWT**; `password-reset/send` requires a valid **password-recovery session**; `validate` / `reset` are public and use the emailed reset `token` in the body
- Email-based identification; responses avoid user enumeration where designed to
- Secure, time-limited reset tokens
- Rate limiting via password-recovery rate-limit services

## Endpoints (engine-relative)

### 1. Create password-recovery session

`POST /auth/password-recovery-session`

Establishes the recovery session used by subsequent reset calls. See request specs under `spec/requests/` for exact payload/envelope.

### 2. Send reset email

`POST /auth/password-reset/send`

**Auth:** Password-recovery session  

**Body (typical):** `{ "email": "string" }`  

**Workflow:** `SendWorkflow` → rate-limit check → `Services::Auth::PasswordReset::Send`

### 3. Validate token

`POST /auth/password-reset/validate`

**Auth:** Public (reset token in body)

**Body (typical):** `{ "token": "string" }` (optional `email` when config requires it)

**Workflow:** `ValidateWorkflow`

### 4. Reset password

`POST /auth/password-reset/reset`

**Auth:** Public (reset token in body)

**Body (typical):** token + new password fields (`passwordConfirmation` / `password_confirmation`)

**Workflow:** `ResetWorkflow`

Success behavior and verifier rotation differ from authenticated [change password](change_password_workflow.md) — treat recovery success per product policy (often force Sign In).

## Errors

Failures return the standard application envelope via `render_application_result`. Status mapping uses Auth identity/password-reset error helpers. Validation failures from deserializers typically surface as `422 Unprocessable Entity`.

## Security notes

- Never log passwords, raw tokens, or recovery-session secrets
- Prefer HTTPS in production
- Respect rate limits; do not probe for account existence in client UX

## Related

- [Change password workflow](change_password_workflow.md)
- [API reference](api_reference.md)
- [Initializing](initializing.md) — secrets / feature config
- [Extending](extending.md)
