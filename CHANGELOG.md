# Changelog

## Unreleased

### Security

- Boot guard: outside development/test the app raises `CommandTower::Errors::InsecureJwtSecretError` when `config.jwt.hmac_secret` is blank or the published default. Temporary escape hatch: `config.jwt.allow_insecure_default_secret` / ENV `COMMAND_TOWER_ALLOW_INSECURE_JWT_SECRET`.
- `user_secrets` now stores an HMAC `secret_digest` (additive migration, unique index); `Secrets::Generate` and `Secrets::Verify` no longer write or read plaintext. Run `command_tower:user_secrets:clear_plaintext` to blank legacy rows.
- Plain-text login does equal bcrypt work for known and unknown identifiers.
- Password-reset and email-verification mail is sent from ActiveJob (`IssueJob`s carry only a normalized email or `user_id`, never the secret). `password-reset/send` always enqueues one job and returns a neutral 200.

- Password login has a per-IP ceiling and a soft per-account lockout (progressive, always expires; unknown identifiers behave the same). Password-reset validate/reset and email-verification verify/send are limited too. A tripped limit returns `429` `auth_rate_limited` with `details.retry_after_seconds` and `Retry-After`. Limits fail open on a Redis outage (`auth.rate_limit.fail_open`). Hosts behind a load balancer must configure `trusted_proxies`.

### Added

- Device sessions: table `command_tower_device_sessions` (additive migration), `config.session.*` (`idle_timeout`, `absolute_timeout`, `last_seen_write_interval`, `enforce`, `upgrade_legacy_tokens`), `sid` claim on login tokens, and `401` codes `session_expired` / `session_revoked` in the client error envelope. Sid-less tokens keep the old rule. A cookie-sourced refresh no longer sends the `X-Authorization-With-Reset` header. See [authentication](docs/authentication.md#device-sessions) and the [upgrade guide](docs/upgrades/0.24.0.md).
- Device session lifecycle: logout revokes only the current device; password change, password reset, admin verifier mutation and tombstone revoke all of a user's sessions (`Services::Auth::DeviceSessions::RevokeAll`). Impersonation start/stop keep the actor's `sid`. The auth cookie now expires at the session's absolute expiry while `X-Authorization-Expire` stays the sliding signal.
- `CommandTower::Auth::DeviceSessions::PurgeEndedJob` (deletes sessions ended more than 7 days ago, in batches of 1,000). Hosts must schedule it; see [authentication](docs/authentication.md#purging-ended-sessions).
- Installation id: the HTTP boundary reads `X-Installation-Id` (then the `ct_installation` cookie, UUID v4 only). A cookie-mode login without one plants an HttpOnly `ct_installation` cookie; a new session replaces the same installation's earlier one and records `X-Client-Platform` / `X-App-Version`. Hosts that list CORS `headers:` explicitly must add `X-Installation-Id`, `X-Client-Platform` and `X-App-Version`.
- Legacy upgrade: `GET /auth/session` gives a valid sid-less token a device session (one row per token under concurrency, expiry `generated_at + absolute_timeout`) and returns a replacement token with a `sid`. Revoking the upgraded session ends the legacy token. Controlled by `config.session.upgrade_legacy_tokens`.
- `config.session.omit_body_token` (ENV `COMMAND_TOWER_SESSION_OMIT_BODY_TOKEN`, default true) and `omit_body_token_min_app_version` (ENV `COMMAND_TOWER_SESSION_OMIT_BODY_TOKEN_MIN_APP_VERSION`, default `0.4.0`): in cookie mode, login omits `token` from the body only for `X-Client-Platform: web` at or above that version.
- `config.login.mail_delivery` (`:later` default, `:inline`).
- `config.login.rate_limits.*` (see [authentication](docs/authentication.md#rate-limits-and-soft-lockout)). A second verification-code request within 60 s sends nothing and answers `200` with `resendAvailableAt`.

### Deprecated

- `config.login.plain_text.lockable` is a no-op; use `config.login.rate_limits`.

See [password reset](docs/password_reset_workflow.md), [email verification](docs/email_verification_workflow.md), [bootstrap 08](docs/bootstrap/08-initializer.md).
