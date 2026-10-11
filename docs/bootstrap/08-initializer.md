# 08 — Initializer

## Purpose

Set **host_key**, secrets, local mail, and (when the client is Command Tower frontend on web) cookies. The generated file documents every class_composer option; do not uncomment the world.

## Prerequisites

- [`07-execution-bases.md`](07-execution-bases.md)
- Secrets from [`04-secrets-and-env.md`](04-secrets-and-env.md) already in Compose

## Files the host edits

`config/initializers/command_tower.rb` (created by install)

In-engine dummy for **shape**: [`../../rails_app/config/initializers/command_tower.rb`](../../rails_app/config/initializers/command_tower.rb). Copy **intent** (host_key, secrets, later RBAC/gates), not the dummy’s engine-dev values as a product identity.

## Procedure

### `host_key` (required)

Server-bound host/product identity for CT-generic user-scoped state (experience states). **Not** client-supplied.

```ruby
CommandTower.configure do |config|
  config.application.host_key = "your_product"
end
```

Blank `host_key` → Me experience-state routes return **503**.

The dummy sets `config.application.host_key = "command_tower"`. A product host uses its **own** key.

### Secrets

Prefer ENV already injected by Compose:

```ruby
config.jwt.hmac_secret = ENV.fetch("SECRET_KEY_BASE")
config.signup_session.jwt_secret = ENV.fetch("SIGNUP_SESSION_JWT_SECRET")
config.password_recovery_session.jwt_secret = ENV.fetch("PASSWORD_RECOVERY_SESSION_JWT_SECRET")
```

Exact setter names are in the generated initializer comments and [`../initializing.md`](../initializing.md). Match those names; do not invent parallel keys.

### Cookies / CSRF (required for Command Tower frontend on web)

Command Tower frontend `defaultSessionStrategy()` is **cookie + CSRF on web** and Bearer on native. If this API will serve that web client, enable cookies **now**. Curl-only smoke in [`12-smoke-check.md`](12-smoke-check.md) can still send `Authorization: Bearer`.

Contract and defaults: [`../cookie_authentication_guide.md`](../cookie_authentication_guide.md). Local HTTP Compose:

```ruby
config.jwt.cookie.enabled = true
config.jwt.cookie.secure = false
config.jwt.cookie.same_site = :lax
config.jwt.cookie.csrf.enabled = true
```

Do not set `secure = true` on `http://localhost`. Leave `domain` nil (host-only). Defaults are `ct_jwt` and `ct_csrf`. Full field table stays in the cookie guide.

A browser stores those cookies by hostname. The port is not part of the key, so two web apps on `localhost` share one `ct_jwt` and one `ct_csrf`. Logout expires both cookies. A second product on the same hostname sets both names, and that host’s frontend `session.csrfCookieName` matches the CSRF name. The header stays `X-CSRF-Token`. A host that runs alone leaves the defaults.

```ruby
config.jwt.cookie.name = "other_jwt"
config.jwt.cookie.csrf.cookie_name = "other_csrf"
```

If the only client is Bearer (`curl`, native-only), leave cookies disabled.

### Email / SMTP

Step 02 already set `:file` delivery in `development.rb`. In the initializer, set the public app URL used in mail links (frontend origin, not the API port):

```ruby
config.application.url = "http://localhost:8081"
```

`8081` is one product’s Expo port. Use the port this host’s web app actually publishes, and put that same origin in `CORS_ALLOWED_ORIGINS` (step 01). Production SMTP is out of this manual’s deployment scope.

### What not to do

- Do not duplicate CommandTower default hashes “for completeness”
- Do not set `FORCE=1` and regenerate after customizing
- Do not fork engine internals because a comment looked optional

RBAC default role and feature gates are steps 09–10.

## Stop

`host_key` is a real product string. JWT and session secrets resolve from ENV. Cookie + CSRF are on if a CT frontend web client will call this API. Next: [`09-rbac.md`](09-rbac.md).
