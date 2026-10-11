# Bootstrap a new Command Tower backend host

Bring up a new Rails API host that **mounts** CommandTower, in order.

This directory is the host bring-up authority. Specialty contracts stay in sibling docs (`initializing`, `authorization`, `api_reference`, `extending`). This tree owns **order**, **which files the host authors** (including Docker and Make), and **how to invoke Rails** — always inside Compose.

Do **not** copy another product host’s tree. Do **not** copy [`../docker-compose.yaml`](../docker-compose.yaml) from this gem (that file is for **engine development**). The dummy app under [`../../rails_app/`](../../rails_app/) is an in-engine example for initializer and RBAC shape, not a product template.

## Docker-only

Every Ruby/Rails action runs inside Docker Compose.

**Host-machine tools:** Docker, the Docker Compose plugin, Make, Git. That is the entire local toolchain.

Do **not** run on the Mac (or any unsandboxed host OS):

- `gem install rails`
- `rails new`
- `bundle`
- `bin/rails` / `bin/rake`
- `rspec` / `rubocop`

Those names appear in this tree as **task names** inside the container, always invoked as `make …`.

**Chicken-and-egg:** author `Dockerfile`, `docker-compose.yml`, and `Makefile` **first** ([`01-docker-make-compose.md`](01-docker-make-compose.md)). `make build` produces a Ruby image. `make rails-new` runs `rails new` **in that image**. Only then pin the gem and install CommandTower.

## This is not deployment

This manual is **local bring-up**. It ends when the host runs in Compose and passes the checks in [`14-sanity-checks.md`](14-sanity-checks.md): `make doctor` and `GET /me` **200** for a member user.

It does **not** cover production deploys, systemd, reverse proxies, LXC, or how secrets are distributed in production. Do not add a deploy step to this tree without a separate decision.

## How to read

1. Follow **Implementation order** below. That list is the only sequence.
2. Open one numbered file per step. Later files assume earlier steps exist.
3. Each step states purpose, prerequisites, files to create, the procedure (`make` only), and the stop condition.
4. For field contracts, follow the linked specialty doc. Do not treat this tree as a second copy of those contracts.

A **platform-proof** host is: Docker/Make, Rails API in the container, CommandTower installed, `host_key`, host RBAC grants, feature gates, register → login → `GET /me`. Product domain and messaging adapters are optional ([`13-optional.md`](13-optional.md)).

Attaching a Command Tower **frontend** is a separate step after this tree: [Local FE↔BE join](../../../artifacts/COMMANDTOWER_LOCAL_JOIN.md).

## Implementation order

| Step | File | What you do |
|------|------|-------------|
| 00 | [`00-ownership.md`](00-ownership.md) | Engine vs host; schema; Docker-only; dummy is not a product template |
| 01 | [`01-docker-make-compose.md`](01-docker-make-compose.md) | Dockerfile, Compose, Makefile, `.dockerignore` |
| 02 | [`02-create-the-rails-app.md`](02-create-the-rails-app.md) | `make rails-new` (Rails 8 API) inside the container |
| 03 | [`03-pin-the-gem.md`](03-pin-the-gem.md) | `gem "command_tower"` from RubyGems (or git tag) |
| 04 | [`04-secrets-and-env.md`](04-secrets-and-env.md) | JWT / signup-session / password-recovery secrets in Compose |
| 05 | [`05-install-migrate-doctor.md`](05-install-migrate-doctor.md) | `command_tower:install`, migrate, doctor |
| 06 | [`06-mount-and-health.md`](06-mount-and-health.md) | Engine mount path; host healthz |
| 07 | [`07-execution-bases.md`](07-execution-bases.md) | Inherit CommandTower controller/job bases |
| 08 | [`08-initializer.md`](08-initializer.md) | `host_key`, cookies if needed, email knobs |
| 09 | [`09-rbac.md`](09-rbac.md) | Host `rbac_groups.yml` grants CT entity names |
| 10 | [`10-roles-and-gates.md`](10-roles-and-gates.md) | Default `member`; enable login / verify / reset gates |
| 11 | [`11-auth-client-path.md`](11-auth-client-path.md) | Bearer vs cookie+CSRF |
| 12 | [`12-smoke-check.md`](12-smoke-check.md) | Register → login → `GET /me` **200** |
| 13 | [`13-optional.md`](13-optional.md) | Optional: messaging, host tests, client-version compatibility |
| 14 | [`14-sanity-checks.md`](14-sanity-checks.md) | Stop: doctor + Me smoke; not deployment |

Step 13 is optional after 12.

## File index

Same files as the table. Filename numbers match the order list. If you add, remove, or reorder a step, change this README and the filenames together.

## Specialty docs this tree does not replace

| Need | Doc |
|------|-----|
| Attach a Command Tower frontend locally | [`../../../artifacts/COMMANDTOWER_LOCAL_JOIN.md`](../../../artifacts/COMMANDTOWER_LOCAL_JOIN.md) |
| What `command_tower:install` does, flags, schema, doctor | [`../initializing.md`](../initializing.md) |
| Layer map, workflow rule | [`../architecture.md`](../architecture.md) |
| Extension points | [`../extending.md`](../extending.md) |
| HTTP catalog | [`../api_reference.md`](../api_reference.md) |
| Route areas | [`../controllers.md`](../controllers.md) |
| RBAC | [`../authorization.md`](../authorization.md), [`../authentication_authorization_guide.md`](../authentication_authorization_guide.md) |
| Cookie / CSRF | [`../cookie_authentication_guide.md`](../cookie_authentication_guide.md) |
| Messaging | [`../messaging_integration_guide.md`](../messaging_integration_guide.md) |
| Testing factories | [`../testing.md`](../testing.md) |
| Admin Workspace | [`../admin_workspace.md`](../admin_workspace.md) |
| Principal capabilities | [`../principal_capabilities.md`](../principal_capabilities.md) |
| Audit registry | [`../audit.md`](../audit.md) |
| Eventing | [`../eventing.md`](../eventing.md) |
| Release upgrades | [`../upgrades/README.md`](../upgrades/README.md) |

Older entry: [`../host_integration_guide.md`](../host_integration_guide.md) is a pointer here.
