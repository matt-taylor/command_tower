# 00 — Ownership

## Purpose

Know what CommandTower owns vs what the host owns **before** you generate a Rails app. Wrong ownership here produces forked platform code and duplicate schema.

## Prerequisites

Read [`README.md`](README.md). This step is conceptual; no files yet.

## Engine vs host

CommandTower is a **mountable Rails engine**. The host is a Rails API application that:

- Depends on the `command_tower` gem
- Runs install/migrate/doctor **inside Compose**
- Mounts the engine
- Configures secrets, RBAC composition, and feature gates
- Adds **product** routes, workflows, and schema

The engine owns:

- CommandTower-owned schema (users, sessions, JWT-related tables, Me/Auth, messaging platform tables, and the rest of the engine `db/migrate`)
- Platform HTTP under the mount
- Workflow / service / serializer framework
- Default entity catalog (`lib/command_tower/authorization/default.yml`)
- Shared FactoryBot definitions

The host owns:

- `Dockerfile`, `docker-compose.yml`, `Makefile`
- Product schema, product routes, product workflows
- `config/initializers/command_tower.rb` after generate
- `config/rbac_groups.yml` (grants of **CT entity names** plus host-owned entities)
- Secrets in Compose / env
- Feature-gate choices
- Messaging catalogs and adapter credentials (optional)

## Schema (AD-SCH-01)

CommandTower is the **sole authoring authority** for CommandTower-owned schema. Hosts must **not** manually write, edit, or copy-paste CommandTower schema migrations.

Hosts install copies via `command_tower:install` / `command_tower:install:migrations`, then `db:migrate`. Installed `*.command_tower.rb` files are an **execution context**, not a second authoring home.

Contract: [`../initializing.md`](../initializing.md).

## Workflow layer

Meaningful business behavior enters through a **workflow**. Controllers, jobs, and scheduled tasks do not call services as a full business action. Workflows do not call other workflows (extract a shared sequence). See [`../architecture.md`](../architecture.md).

Do not invent a parallel “manager” layer.

## Dummy `rails_app` is not a product template

[`../../rails_app/`](../../rails_app/) is the **in-engine dummy host** used to develop and test the gem. Later steps cite its initializer and `rbac_groups.yml` for **shape**.

Do not copy `rails_app/` as a new product. Do not copy this gem’s [`docker-compose.yaml`](../../docker-compose.yaml) (`mysql:latest`, engine ports) — that file is for **engine development**, not a product host.

This tree writes **generic** Makefile / Compose templates in [`01-docker-make-compose.md`](01-docker-make-compose.md).

## Docker-only

No Ruby or Rails on the host OS. See the README **Docker-only** section. Step 01 exists so `rails new` never runs on the Mac.

## What a platform-proof host is

Enough to:

1. Boot in Compose
2. Pass `make doctor`
3. Register, log in, and receive **200** from `GET /me` as a `member`

Product domain, Solid Queue workers, SMS/Pushover adapters, and admin RBAC bundles are **not** required to finish this manual.

## Stop

You can explain engine vs host, AD-SCH-01, and why Docker exists before `rails new`. Next: [`01-docker-make-compose.md`](01-docker-make-compose.md).
