# 04 — Secrets and env

## Purpose

Give Compose the secrets CommandTower **doctor** requires. Without them, install may succeed and doctor will fail.

## Prerequisites

- [`03-pin-the-gem.md`](03-pin-the-gem.md)
- Compose file from [`01-docker-make-compose.md`](01-docker-make-compose.md)

## Files the host creates / edits

| File | Role |
|------|------|
| `.env` (gitignored) | Local values interpolated by Compose |
| `.env.example` (committed, no secrets) | Names only |
| `docker-compose.yml` `environment:` | Already stubbed in step 01 |

Required (names match [`../initializing.md`](../initializing.md)):

| Secret | Typical env | Used for |
|--------|-------------|----------|
| JWT HMAC | `SECRET_KEY_BASE` (or `config.jwt.hmac_secret`) | Access tokens |
| Signup-session JWT | `SIGNUP_SESSION_JWT_SECRET` | Email verification / signup session |
| Password-recovery JWT | `PASSWORD_RECOVERY_SESSION_JWT_SECRET` | Password reset session |

Doctor checks these. Failures abort with remediation text.

`.env.example`:

```
SECRET_KEY_BASE=
SIGNUP_SESSION_JWT_SECRET=
PASSWORD_RECOVERY_SESSION_JWT_SECRET=
```

Generate long random values for `.env`. Do not commit `.env`. Do not reuse production secrets in development.

The initializer generated in step 05 can read these via `ENV.fetch`. You do not need a complete initializer yet.

Optional later: SMTP, SMS, Pushover credentials — [`13-optional.md`](13-optional.md) and [`../messaging_integration_guide.md`](../messaging_integration_guide.md). Not required for `GET /me`.

This step is **local** env for Compose. Production secret distribution is out of scope ([README](README.md#this-is-not-deployment)).

## Procedure

1. Create `.env` with three distinct secrets.
2. Confirm `docker-compose.yml` passes them into `api`.
3. Recreate the api container if it was already running:

```bash
make halt
make build
```

## Stop

Compose interpolates the three secrets into `api`. Next: [`05-install-migrate-doctor.md`](05-install-migrate-doctor.md).
