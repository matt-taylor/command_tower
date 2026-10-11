# 05 — Install, migrate, doctor

## Purpose

Copy engine migrations, generate the initializer (and default mount unless skipped), migrate, and run doctor. **Invocation is Make.** The contract for flags and schema is [`../initializing.md`](../initializing.md) — do not treat this page as a second copy of that contract.

## Prerequisites

- [`04-secrets-and-env.md`](04-secrets-and-env.md)
- Database service healthy (`make` recipes that run Rails will start `depends_on`)

## Files this step creates

| File | Role |
|------|------|
| `db/migrate/*command_tower.rb` | Installed copies of engine migrations (do not hand-edit) |
| `config/initializers/command_tower.rb` | Generated unless `SKIP_CONFIGURE=1` |
| Engine mount in `config/routes.rb` | Unless `SKIP_MOUNT=1` or `--skip-routes` |

`command_tower:install` does **not** run `db:migrate`. Installing and migrating stay separate on purpose.

## Procedure

If the host will own `GET /api/healthz` (or any route that must be declared **before** the engine mount), skip the generator mount and add routes in [`06-mount-and-health.md`](06-mount-and-health.md):

```bash
make rails ARGS='command_tower:install' SKIP_MOUNT=1
```

Otherwise:

```bash
make rails ARGS='command_tower:install'
```

Then:

```bash
make db-prepare
make migrate
make doctor
```

`db-prepare` creates the development database if needed. `migrate` applies host and CommandTower migrations.

Existing customized hosts (initializer and mount already present):

```bash
make rails ARGS='command_tower:install' SKIP_CONFIGURE=1
make migrate
make doctor
```

`FORCE=1` overwrites `config/initializers/command_tower.rb` — do not use it after you have customized the initializer unless you intend to regenerate.

The **task name** inside the container is `bin/rails command_tower:install`. Operators never type that on the Mac.

### What install does (summary)

1. `command_tower:install:migrations` — copies engine migrations with `*.command_tower.rb` scope.
2. `rails g command_tower:configure` unless skipped — initializer + mount.
3. Prints next steps.

Full flag table: [`../initializing.md`](../initializing.md).

Doctor checks Rails compatibility, engine baseline migrations, host-installed copies, JWT / session secrets, and messaging adapter names. It does **not** probe Redis/SMTP connectivity.

## In-engine dummy

Generated initializer shape: [`../../rails_app/config/initializers/command_tower.rb`](../../rails_app/config/initializers/command_tower.rb). That file is a dummy-host example, not a product dump.

## Stop

Install is idempotent if re-run. Migrations applied. `make doctor` exits 0 (or you have a documented doctor failure you will fix in steps 08–10). Next: [`06-mount-and-health.md`](06-mount-and-health.md).
