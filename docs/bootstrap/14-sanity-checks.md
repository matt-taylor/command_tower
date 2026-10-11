# 14 — Sanity checks

## Purpose

Stop condition for **local** bootstrap. This is not a production launch checklist.

## Prerequisites

- Steps 00–12 complete
- Step 13 only if you opted in

## Checks

Run inside Compose (Make wrappers from [`01-docker-make-compose.md`](01-docker-make-compose.md)):

| Check | Command | Expect |
|-------|---------|--------|
| Doctor | `make doctor` | Exit 0 |
| Server | `make server` | API listens on the Compose port |
| Me smoke | [`12-smoke-check.md`](12-smoke-check.md) | `GET /me` **200** |
| Host specs (if you added them) | `make rspec` | Pass |
| RuboCop (if you added it) | `make rubocop` | Pass |

401 vs 403 vs 404: still [`12-smoke-check.md`](12-smoke-check.md).

## Not this manual

Do not treat the following as remaining bootstrap steps:

- Production deploys, systemd, reverse proxies, LXC
- Production secret distribution
- Multi-host clustering
- App-store / frontend release (see the Command Tower **frontend** bootstrap tree)

## After this tree

- Product routes and workflows: [`../extending.md`](../extending.md), [`../architecture.md`](../architecture.md)
- HTTP you did not smoke: [`../api_reference.md`](../api_reference.md)
- Gem upgrades: [`../upgrades/README.md`](../upgrades/README.md)
- Command Tower frontend on this API: [Local FE↔BE join](../../../artifacts/COMMANDTOWER_LOCAL_JOIN.md)

## Stop

Doctor is green and `GET /me` is **200**. Local Command Tower backend bootstrap is complete.
