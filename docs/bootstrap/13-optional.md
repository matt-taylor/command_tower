# 13 — Optional (messaging, tests, client-version compatibility)

## Purpose

After `GET /me` works, add platform extras **only if the product needs them**. A platform-proof host may skip this file and run [`14-sanity-checks.md`](14-sanity-checks.md).

## Prerequisites

- [`12-smoke-check.md`](12-smoke-check.md) passed

Do not start here. Messaging and CVC assume install, RBAC, and gates already exist.

## Messaging

When the host **emits** notifications or uses phone/Pushover:

- Catalog, channel policy, adapters, credentials: [`../messaging_integration_guide.md`](../messaging_integration_guide.md)
- Admin announcements: [`../admin_workspace.md`](../admin_workspace.md)

Complete steps 00–12 first. This bootstrap tree does not duplicate the messaging guide.

## Home notices prune

When the host enables `config.home_notices`, schedule the prune daily. CommandTower ships no scheduler.

```bash
make rake TASK=command_tower:home_notices:prune
```

(Inside this gem's dummy app the task is `app:command_tower:home_notices:prune`.)

Or enqueue `CommandTower::HomeNotices::PruneEndedJob` from the host scheduler. It deletes ended notice rows idle for 180 days, in batches. Contract: [`../home_notices.md`](../home_notices.md).

## Host tests

Shared FactoryBot definitions ship with the gem. In the host test boot path:

```ruby
require "command_tower/testing"
CommandTower::Testing.install!
```

Then `FactoryBot.modify` as needed. Contract: [`../testing.md`](../testing.md).

Run specs **in Compose**:

```bash
make rspec
make spec SPEC=spec/path/to/file_spec.rb
```

Do not run `rspec` on the Mac.

## Client-version compatibility (CVC)

If the frontend must block incompatible native/web builds, register CVC in the host (registry / initializer). Frontend recovery UX is a client concern; the backend must serve the compatibility contract the client expects.

Follow the gem’s registry comments and [`../extending.md`](../extending.md) for `config.registry` patterns. Do not invent a parallel version table.

## Stop

Either you skipped this step, or messaging/tests/CVC point at specialty docs and run via Make. Next: [`14-sanity-checks.md`](14-sanity-checks.md).
