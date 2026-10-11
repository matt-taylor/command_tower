# 12 — Smoke check (`GET /me`)

## Purpose

Prove the host is a usable Me/Auth API: register, log in, call `GET /me`, receive **200**.

## Prerequisites

- Steps 00–11
- API listening: `make server` (or `make s`) — Puma bound on `0.0.0.0` (step 01)

Prefix every path with your engine mount (`/api` if you mounted there). Examples below assume mount at `/api` and host port **3000**.

HTTP catalog (full contract): [`../api_reference.md`](../api_reference.md). This page is the **happy path only**.

## Procedure

Run `curl` **on the Mac** against the published Compose port. That is HTTP, not Ruby on the host.

Login succeeds with **201** (not 200). Register succeeds with **201** and **no** token.

### 1. Register

```bash
curl -sS -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Ada",
    "last_name": "Lovelace",
    "username": "ada1",
    "email": "ada@example.com",
    "password": "password12",
    "password_confirmation": "password12"
  }'
```

Expect **201**. No JWT. If email verification is required immediately (`verify_email_required_within = 0.minutes`), either verify using the code in `tmp/mails` or raise the grace period (step 10).

If you already have a user in the database, skip to login.

### 2. Login

```bash
curl -sS -X POST http://localhost:3000/api/auth/plain-text/login \
  -H "Content-Type: application/json" \
  -d '{"identifier": "ada@example.com", "password": "password12"}'
```

Expect **201** and `data.token`. Cookie mode also sets `Set-Cookie` for `ct_jwt` (and `ct_csrf` when CSRF is on).

### 3. Me

```bash
TOKEN='<paste data.token>'
curl -sS -H "Authorization: Bearer ${TOKEN}" http://localhost:3000/api/me
```

Expect **200** and a Me payload.

Cookie mode: omit `Authorization`, send `-b cookies.txt` after login with `-c cookies.txt`, and on mutating requests add `-H "X-CSRF-Token: …"` from the CSRF cookie. `GET /me` still needs the JWT cookie.

## How to read failures

| Status | Meaning |
|--------|---------|
| **401** | Not authenticated — missing/invalid token or cookie |
| **403** | Authenticated but **not authorized** — RBAC grant missing (`me` not on the user’s role) |
| **404** | Feature gate off or wrong path/mount |
| **412** | Email verification required — grace period elapsed; verify or raise `verify_email_required_within` |
| **503** | Often blank `host_key` on experience-state routes; fix step 08 |
| Connection refused | Compose `command` not binding `0.0.0.0`, or published port mismatch |

Do not “fix” 403 by disabling RBAC. Grant `me` on `member`.

## After `GET /me`

Attaching a Command Tower frontend is **not** this file. Follow [Local FE↔BE join](../../../artifacts/COMMANDTOWER_LOCAL_JOIN.md).

## Stop

`GET /me` is **200** for a `member` user. Optional extras: [`13-optional.md`](13-optional.md). Required wrap-up: [`14-sanity-checks.md`](14-sanity-checks.md).
