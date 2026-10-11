# 06 — Mount and health

## Purpose

Mount CommandTower where the product needs it, and keep a host health endpoint **outside** the engine when you skipped the generator mount.

## Prerequisites

- [`05-install-migrate-doctor.md`](05-install-migrate-doctor.md)

## Files the host edits

`config/routes.rb`

## Procedure

### Default (generator mounted)

`command_tower:install` without `SKIP_MOUNT` typically mounts:

```ruby
mount CommandTower::Engine => "/api"
```

or at `/`, depending on generator defaults. Confirm the file. Engine routes then live under that prefix (`GET /api/me` vs `GET /me`).

Use **one** mount. Do not mount the engine twice.

### Host-owned healthz (`SKIP_MOUNT=1`)

Declare host routes **before** the engine so health checks never depend on engine routing:

```ruby
Rails.application.routes.draw do
  get "/api/healthz", to: "health#show"

  mount CommandTower::Engine => "/api"
end
```

`HealthController#show` is host-owned (liveness). Keep it trivial.

If the engine is mounted at `/`, a host `/healthz` still belongs **before** the mount.

### Accidental public mount

If you mounted at `/` and needed `/api`, or the generator mounted when you needed to skip: fix `config/routes.rb` by hand. Re-running configure with `FORCE=1` is not the tool for route cleanup.

More on mount mistakes: [`../initializing.md`](../initializing.md) troubleshooting.

## Stop

`config/routes.rb` has exactly one engine mount at the prefix your API and frontend will call. Host `healthz` (if any) is declared before that mount. Next: [`07-execution-bases.md`](07-execution-bases.md).
