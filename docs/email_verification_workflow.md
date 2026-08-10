# Email Verification Workflow

Code-based email verification ensures the user can receive mail at their registered address. Users authenticate with JWT; a configurable grace period may allow API access before verification is mandatory.

## Purpose and orchestration

| Step | Route | Workflow |
|------|-------|----------|
| Send code | `POST /auth/email-verification/send` | `Workflows::Auth::EmailVerification::SendWorkflow` |
| Verify code | `POST /auth/email-verification/verify` | `Workflows::Auth::EmailVerification::VerifyWorkflow` |

Both workflows inherit `ApplicationWorkflow` with `retry_strategy :none`.

| Item | Value |
|------|--------|
| Controllers | `CommandTower::Auth::EmailVerification::SendController` / `VerifyController` |
| Auth | Authentication + authorization boundaries; send bypasses email-validation precondition so unverified users can request codes |
| Feature gate | `CommandTower.config.login.plain_text.email_verify?` |

**Boundary:** Controllers authenticate/authorize, run **one** workflow, render results. Workflows orchestrate verification services. Hosts do not reopen JWT or email-verification framework internals — see [extending.md](extending.md).

## Key characteristics

- **Method:** Numeric code (length configurable; commonly 6 digits)
- **Delivery:** Email to the registered address
- **Expiration:** Configurable (commonly ~10 minutes)
- **Authentication required:** Valid JWT
- **Grace period:** Configurable window before verification is enforced on other routes

## Endpoints (engine-relative)

### Send

`POST /auth/email-verification/send`

No body typically required (uses `current_user`). Returns a message payload on success.

### Verify

`POST /auth/email-verification/verify`

**Body (typical):** `{ "code": "string" }`  

On success, marks the user’s email validated.

## Errors

Standard application envelope. Invalid codes and validation failures map through Auth identity error status helpers. See [API reference](api_reference.md) for envelope shape.

## Configuration

Email verification options live on CommandTower config (enablement, code length, TTL, grace period). Hosts set secrets and product mail delivery via initializer — [initializing.md](initializing.md).

## Related

- [API reference](api_reference.md)
- [Authentication](authentication.md)
- [Extending](extending.md)
