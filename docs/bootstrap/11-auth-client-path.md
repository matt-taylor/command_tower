# 11 — Auth client path

## Purpose

Pick **one** client authentication mode and configure the host to match. Mixing a cookie+CSRF frontend with cookies disabled will fail in the browser. `curl` can still send Bearer on the same host.

## Prerequisites

- [`10-roles-and-gates.md`](10-roles-and-gates.md)
- `gem "rack-cors"` from [`02-create-the-rails-app.md`](02-create-the-rails-app.md) if a browser will call this API

## Two supported modes

| Mode | Client sends | Host initializer |
|------|----------------|------------------|
| Bearer | `Authorization: Bearer <jwt>` | Cookie JWT disabled |
| Cookie + CSRF | HttpOnly JWT cookie + CSRF header/cookie | Cookie + CSRF **enabled** (step 08) |

Command Tower **frontend** on web uses `defaultSessionStrategy()` → cookie + CSRF. Native uses Bearer. Enable cookies when that web client exists; keep Bearer working for `curl` and native.

Contract: [`../cookie_authentication_guide.md`](../cookie_authentication_guide.md).

Do not invent a third session store. Do not put JWTs in `localStorage` as a “simpler cookie.”

## Procedure

1. If the client is Command Tower frontend on web: cookies + CSRF already on from step 08 (`secure = false` on HTTP localhost).
2. If Bearer-only: leave cookies disabled; step 12 uses `Authorization`.
3. If a **browser on another origin** calls the API, add host CORS. CommandTower does not ship CORS.

`config/initializers/cors.rb`:

```ruby
allowed_origins = ENV.fetch(
  "CORS_ALLOWED_ORIGINS",
  "http://localhost:8081,http://localhost:8082,http://localhost:19006"
).split(",").map(&:strip).reject(&:empty?)

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)
    resource "*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: true,
             expose: ["X-Authorization-Expire", "X-Authorization-Reset"]
  end
end
```

`credentials: true` requires an **explicit origin list**, not `*`. Compose already passes `CORS_ALLOWED_ORIGINS` from step 01. The sample origins `8081`, `8082`, and `19006` belong to one web product. Add the origin this Expo web app actually uses, and keep it aligned with `config.application.url` and the API’s published port.

Attaching a Command Tower frontend: [Local FE↔BE join](../../../artifacts/COMMANDTOWER_LOCAL_JOIN.md).

## Stop

You can state which mode the smoke will use. CORS exists if a browser will call this API. Next: [`12-smoke-check.md`](12-smoke-check.md).
