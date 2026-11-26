# Cookie Authentication Guide

HttpOnly cookie authentication for browser / SPA hosts. Mobile and API clients typically use Bearer tokens only.

Back to [README](../README.md). Endpoint contracts: [API reference](api_reference.md). Deep authn/RBAC: [authentication_authorization_guide.md](authentication_authorization_guide.md).

Journey coverage: `spec/integration_test/auth/cookie_*.rb`.

## Enable cookies

```ruby
CommandTower.configure do |config|
  config.jwt.cookie.enabled = true
  # Optional CSRF for cookie-authenticated unsafe methods:
  # config.jwt.cookie.csrf.enabled = true
end
```

### Defaults

| Setting | Default |
|---------|---------|
| `jwt.ttl` | `7.days` |
| `jwt.cookie.enabled` | `false` |
| `jwt.cookie.name` | `"ct_jwt"` |
| `jwt.cookie.same_site` | `:lax` |
| `jwt.cookie.secure` | `false` (set `true` in production / HTTPS) |
| `jwt.cookie.httponly` | `true` |
| `jwt.cookie.path` | `"/"` |
| `jwt.cookie.domain` | `nil` (host-only) |
| `jwt.cookie.ttl` | `7.days` |
| `jwt.cookie.csrf.enabled` | `false` |
| `jwt.cookie.csrf.cookie_name` | `"ct_csrf"` |
| `jwt.cookie.csrf.header_name` | `"X-CSRF-Token"` |
| `jwt.cookie.csrf.rotate_on_login` | `true` |
| `jwt.cookie.csrf.rotate_on_reset` | `true` |
| CSRF `same_site` / `secure` / `path` / `domain` | `nil` (inherit JWT cookie) |
| CSRF `ttl` | `7.days` |

### Two web apps on one hostname

The browser keys `ct_jwt` and `ct_csrf` by hostname. The port is not part of that key. Two Command Tower web apps on `localhost` overwrite each other’s session. Logout expires both cookies, so a shared CSRF name still logs the other app out on its next POST.

A second product sets both names. The frontend `session.csrfCookieName` matches `csrf.cookie_name`. Leave `header_name` as `X-CSRF-Token`. A host that runs alone keeps `ct_jwt` and `ct_csrf`.

```ruby
config.jwt.cookie.name = "other_jwt"
config.jwt.cookie.csrf.cookie_name = "other_csrf"
```

## Token extraction order

1. `Authorization: Bearer <token>` header (wins when present)
2. HttpOnly JWT cookie when cookie mode is enabled

## Sessions and the cookie

Login starts a device session and the JWT carries its `sid`. The session's idle and absolute timeouts (`config.session`) decide when it ends; see [Authentication](authentication.md#device-sessions). When a session has ended, the API answers `401` with code `session_expired` or `session_revoked` in the envelope `{ "data": null, "errors": [{ "code", "message" }] }`, and clears the cookie.

On a cookie-sourced `GET /auth/session` refresh the new token is set in the cookie only. The `X-Authorization-With-Reset` response header is sent only when the request used a bearer token.

## Installation id and body token

The HTTP boundary reads an installation id from the `X-Installation-Id` header first, then the `ct_installation` cookie. Only a UUID v4 is accepted; anything else is ignored. A cookie-mode login that arrives without an id gets a fresh one and sets `ct_installation` (HttpOnly, 400 days, same `SameSite` / `Secure` / `domain` options as the auth cookie). When the client already sent the header (native), no cookie is set. Starting a session replaces the same installation's earlier session and records the `X-Client-Platform` and `X-App-Version` values.

In cookie mode, `POST /auth/plain-text/login` omits `token` from the body (`tokenExpiresAt` stays) only when `X-Client-Platform` is `web` and `X-App-Version` is at or above `config.session.omit_body_token_min_app_version` (default `0.4.0`, ENV `COMMAND_TOWER_SESSION_OMIT_BODY_TOKEN_MIN_APP_VERSION`). Turn the behavior off with `config.session.omit_body_token = false` (ENV `COMMAND_TOWER_SESSION_OMIT_BODY_TOKEN=false`). Native clients, older web clients and requests without the headers keep the body token.

## Legacy token upgrade

`GET /auth/session` with a valid sid-less (legacy) token creates a device session for it and returns a replacement token that carries the `sid` (set in the cookie, or in `X-Authorization-With-Reset` for bearer). The session row is keyed by the legacy token's `generated_at`, so concurrent upgrades produce one session, and it expires at `generated_at + absolute_timeout`. The upgrade wins over a plain refresh and never rotates the CSRF cookie. Revoking the upgraded session also ends the legacy token (`401` `session_revoked`). Disable with `config.session.upgrade_legacy_tokens = false` (ENV `COMMAND_TOWER_SESSION_UPGRADE_LEGACY_TOKENS=false`).

## Login / logout examples

Paths are engine-relative. Prefix with your mount (generator often mounts at `/`; hosts may use `/api`).

Plain-text login is gated by `config.login.plain_text.enable?`.

### Login

```http
POST /auth/plain-text/login
Content-Type: application/json

{ "identifier": "user@example.com", "password": "secret" }
```

Success **201** envelope:

```json
{
  "data": {
    "user": {
      "id": 1,
      "email": "user@example.com",
      "username": "user",
      "firstName": "Ada",
      "lastName": "Lovelace",
      "emailValidated": true,
      "roles": ["member"]
    },
    "token": "<jwt>",
    "tokenExpiresAt": "<iso8601>"
  },
  "meta": {},
  "errors": []
}
```

When cookies are enabled, the response also sets the JWT cookie (and may set/rotate CSRF cookie). Clients that rely on cookies should use `credentials: "include"` (fetch) / `withCredentials: true` (axios).

### Current user

```http
GET /me
Authorization: Bearer <jwt>
```

Or rely on the JWT cookie when cookie mode is enabled and no Bearer header is sent.

### Logout (this browser)

```http
POST /auth/logout
```

Success **200**:

```json
{
  "data": { "message": "logged_out" },
  "meta": {},
  "errors": []
}
```

Clears the auth cookie for this client. It does **not** rotate `verifier_token`, so other devices’ JWTs remain valid until expiry or verifier rotation.

### Logout everywhere

Rotate the verifier via authenticated password change:

```http
PATCH /me/password
```

Or call `user.reset_verifier_token!` from trusted host ops. There is no `POST /user/modify` engine route.

See [sensitive_routes.md](sensitive_routes.md).

## CSRF (optional)

When `jwt.cookie.csrf.enabled` is true, cookie-authenticated **unsafe** methods (POST/PATCH/PUT/DELETE) require:

1. Non-HttpOnly CSRF cookie (`ct_csrf` by default)
2. Matching header (`X-CSRF-Token` by default)

Mismatch / missing → auth failure with codes such as `csrf_missing` / `csrf_mismatch` (envelope via modern auth boundaries).

Bearer-header requests do not require CSRF.

## CORS

Browser SPA on another origin needs host CORS that allows credentials and your frontend origin. Example sketch (host-owned):

```ruby
# Host rack-cors or equivalent — illustrative only
allow do
  origins "https://app.example.com"
  resource "*",
    headers: :any,
    methods: [:get, :post, :put, :patch, :delete, :options],
    credentials: true,
    expose: ["X-Authorization-Expire", "X-Authorization-Reset"]
end
```

`headers: :any` covers the `X-Time-Zone`, `X-UI-Catalog`, `X-Installation-Id`, `X-Client-Platform` and `X-App-Version` request headers. A host that lists allowed headers explicitly must add all five.

`SameSite=None` cookies require `Secure=true` (HTTPS). Prefer same-site deployments with `SameSite=Lax` when possible.

## Production checklist

- [ ] `jwt.cookie.enabled = true` only when browsers need cookies
- [ ] `jwt.cookie.secure = true` on HTTPS
- [ ] Review `same_site` for cross-site SPAs
- [ ] Enable CSRF if cookies authenticate mutating requests from browsers
- [ ] CORS credentials + explicit origin (not `*`)
- [ ] Do not log tokens or CSRF secrets

## Related

- [API reference](api_reference.md)
- [Authentication](authentication.md)
- [Authentication & authorization guide](authentication_authorization_guide.md)
- [Sensitive changes](sensitive_routes.md)
- [Initializing](initializing.md)
