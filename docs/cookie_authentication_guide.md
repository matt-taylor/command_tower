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

## Token extraction order

1. `Authorization: Bearer <token>` header (wins when present)
2. HttpOnly JWT cookie when cookie mode is enabled

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
