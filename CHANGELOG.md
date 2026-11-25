# Changelog

## Unreleased

### Security

- Boot guard: outside development/test the app raises `CommandTower::Errors::InsecureJwtSecretError` when `config.jwt.hmac_secret` is blank or the published default. Temporary escape hatch: `config.jwt.allow_insecure_default_secret` / ENV `COMMAND_TOWER_ALLOW_INSECURE_JWT_SECRET`.
- `user_secrets` now stores an HMAC `secret_digest` (additive migration, unique index); `Secrets::Generate` and `Secrets::Verify` no longer write or read plaintext. Run `command_tower:user_secrets:clear_plaintext` to blank legacy rows.
- Plain-text login does equal bcrypt work for known and unknown identifiers.
- Password-reset and email-verification mail is sent from ActiveJob (`IssueJob`s carry only a normalized email or `user_id`, never the secret). `password-reset/send` always enqueues one job and returns a neutral 200.

### Added

- `config.login.mail_delivery` (`:later` default, `:inline`).

See [password reset](docs/password_reset_workflow.md), [email verification](docs/email_verification_workflow.md), [bootstrap 08](docs/bootstrap/08-initializer.md).
