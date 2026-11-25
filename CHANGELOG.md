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
- `CommandTower::Auth::DeviceSessions::PurgeEndedJob` (deletes sessions ended more than 30 days ago, in batches of 1,000). Hosts must schedule it; see [authentication](docs/authentication.md#purging-ended-sessions).
- Installation id: the HTTP boundary reads `X-Installation-Id` (then the `ct_installation` cookie, UUID v4 only). A cookie-mode login without one plants an HttpOnly `ct_installation` cookie; a new session replaces the same installation's earlier one and records `X-Client-Platform` / `X-App-Version`. Hosts that list CORS `headers:` explicitly must add `X-Installation-Id`, `X-Client-Platform` and `X-App-Version`.
- Legacy upgrade: `GET /auth/session` gives a valid sid-less token a device session (one row per token under concurrency, expiry `generated_at + absolute_timeout`) and returns a replacement token with a `sid`. Revoking the upgraded session ends the legacy token. Controlled by `config.session.upgrade_legacy_tokens`.
- `config.session.omit_body_token` (ENV `COMMAND_TOWER_SESSION_OMIT_BODY_TOKEN`, default true) and `omit_body_token_min_app_version` (ENV `COMMAND_TOWER_SESSION_OMIT_BODY_TOKEN_MIN_APP_VERSION`, default `0.4.0`): in cookie mode, login omits `token` from the body only for `X-Client-Platform: web` at or above that version.
- Password and email policy: length bounds are now inclusive (defaults password 8–64, email 3–254; `GET /auth/identity-policy` no longer adds or subtracts 1). Passwords are checked against a bundled top-100k common-password list (`config.login.plain_text.password_blocklist_paths`) in register, password reset and change-password. `User` normalizes `email` and validates its format and length.
- `GET /auth/identity-policy` v2: `maxBytes`, `passwordRules`, per-field `rules` (`{ id, label, check }`) and username `selfService` / `selfChange` / `prompt` (`config.username.self_service`, `self_change`, `prompt`).
- `POST /auth/password-check` returns `{ valid, failures, message }` for live password feedback (60 per minute per IP, fails open). The password is never logged.
- `config.login.mail_delivery` (`:later` default, `:inline`).
- `config.login.rate_limits.*` (see [authentication](docs/authentication.md#rate-limits-and-soft-lockout)). A second verification-code request within 60 s sends nothing and answers `200` with `resendAvailableAt`.

- `POST /auth/register` takes `email` + `password` and optional `start_session` (login-shaped session in the response); adds `passwordRulesFailed`, a friendly existing-email message, a per-email rate limit (`config.login.rate_limits.register_attempts_per_email`) and `retry_after_seconds` on `signup_ip_rate_limited`. The six-field body is still accepted.
- `passwordConfirmation` is optional on `POST /auth/password-reset/reset` and `PATCH /me/password`; when sent it must match.
- `command_tower.auth.legacy_contract_used` event on deprecated endpoints, authorization schemes, the old register shape and valid sid-less tokens. `auth.device_session` is seeded in the client-compatibility registry (observe).
- Self-service username: `PATCH /me/username` and `GET /me/username/availability` (authenticated, bypass the email-verification `412` gate), gated by `config.username.self_service` / `self_change`. Errors `username_taken` (422) and `username_change_not_allowed` (403); 10 changes per hour per user; audit event `username_set`. `GET /me` `capabilities.editUsername` is now backed by the same eligibility, and `POST /auth/register` with `start_session` returns `capabilities.editUsername`. New RBAC entities `me_username` and `me_username_availability`; hosts must grant them.
- Rake tasks `command_tower:users:email_duplicates`, `add_email_unique_index` and `normalize_emails`. See the [upgrade guide](docs/upgrades/0.24.0.md).

### Deprecated

- `POST /auth/signup-session`, `POST /auth/password-recovery-session`, `GET /auth/email/availability`, `GET /auth/username/availability`, the `Signup` / `Recovery` authorization schemes, and the register fields `first_name`, `last_name`, `username`, `password_confirmation`.
- `config.login.plain_text.lockable` is a no-op; use `config.login.rate_limits`.

See [password reset](docs/password_reset_workflow.md), [email verification](docs/email_verification_workflow.md), [bootstrap 08](docs/bootstrap/08-initializer.md).
