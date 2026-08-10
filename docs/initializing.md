# Initializing CommandTower

CommandTower is a Rails engine. The install flow below gets the engine **mounted, migrated, and doctor-checked**. That alone is not a fully usable Me/Auth host — complete RBAC, feature gates, and a smoke check via the [Host integration guide](host_integration_guide.md).

Back to [README](../README.md).

## Quick start

```bash
# Gemfile: gem "command_tower"  (or path/git source)
bundle install

bin/rails command_tower:install
bin/rails db:migrate
bin/rails command_tower:doctor
```

`command_tower:install` does **not** run `db:migrate`. Installing and migrating stay separate on purpose.

### After install

Continue with [Host integration](host_integration_guide.md):

1. Host `rbac_groups.yml` (required — otherwise authenticated Me/Auth calls **403**)
2. Assign host roles (for example `member`) on users
3. Enable feature gates you need (login, reset, availability, …)
4. Smoke-check `GET /me` with a Bearer token
5. Wire messaging catalog/adapters when you emit or use phone/Pushover

### What `command_tower:install` does

1. Runs Rails-native `command_tower:install:migrations` (copies engine migrations into the host `db/migrate/` with `*.command_tower.rb` scope).
2. Runs `rails g command_tower:configure` unless skipped (creates initializer; mounts the engine).
3. Prints next steps.

### Flags / environment

| Variable | Effect |
|----------|--------|
| `SKIP_CONFIGURE=1` | Migrations only (existing custom initializer / mount) |
| `SKIP_MOUNT=1` | Generate initializer but do not mount routes |
| `FORCE=1` | Overwrite an existing `config/initializers/command_tower.rb` |

Examples:

```bash
SKIP_CONFIGURE=1 bin/rails command_tower:install
SKIP_MOUNT=1 bin/rails command_tower:install
FORCE=1 bin/rails command_tower:install
```

## Configure generator (optional)

Prefer `command_tower:install` for greenfield hosts. The generator remains available:

```bash
bin/rails generate command_tower:configure
bin/rails generate command_tower:configure --skip-routes
bin/rails generate command_tower:configure --force
```

The generator:

1. Adds `config/initializers/command_tower.rb` when missing (or overwrites with `--force`).
2. Mounts `CommandTower::Engine` unless `--skip-routes` or already mounted.

Dummy-host example initializer (engine development): [`rails_app/config/initializers/command_tower.rb`](../rails_app/config/initializers/command_tower.rb).

## Database migrations

CommandTower is the **sole authoring authority** for CommandTower-owned schema (`db/migrate` inside the gem). Hosts must **not** manually write, edit, or copy-paste CommandTower schema migrations (**AD-SCH-01**).

### Fresh host install

Handled by `command_tower:install` (step 1). Equivalent migration-only command:

```bash
bin/rails command_tower:install:migrations
bin/rails db:migrate
```

`command_tower:install:migrations` is the standard Rails engine task (wrapper around `railties:install:migrations`). Re-running installation is **idempotent**: already-installed CommandTower migrations are skipped.

Rails may **retimestamp** newly copied host files. That is normal. Do not hand-edit installed `*.command_tower.rb` files.

### Upgrade workflow

1. Bump/release the CommandTower gem dependency in the host.
2. Run `bin/rails command_tower:install:migrations` (or `SKIP_CONFIGURE=1 bin/rails command_tower:install`).
3. Run `bin/rails db:migrate`.
4. Optionally run `bin/rails command_tower:doctor`.

Do not re-run configure on hosts that already customize the initializer unless you intend to regenerate it (`FORCE=1`).

### Adding future migrations

1. Author the migration **only** in CommandTower `db/migrate/`.
2. Release / bump the gem in the host.
3. Install + migrate as above.

Installed host copies are an **execution context**, not a second authoring home.

## Configuration

Required for production-ready hosts:

- `config.jwt.hmac_secret` — typically `SECRET_KEY_BASE` / `Rails.application.secret_key_base`
- `config.signup_session.jwt_secret` — or `SIGNUP_SESSION_JWT_SECRET`
- `config.password_recovery_session.jwt_secret` — or `PASSWORD_RECOVERY_SESSION_JWT_SECRET`

Optional / feature-gated:

- Messaging SMS / Pushover adapters and credential resolution (`config.credentials.*` or ENV)
- Cookie + CSRF JWT modes
- Admin enablement, application URL, welcome content hooks

The generated initializer documents available options via class_composer. Defaults live in CommandTower; do not duplicate them unnecessarily in the host.

## Doctor

```bash
bin/rails command_tower:doctor
```

Checks Rails version compatibility, engine baseline migrations, host-installed migration copies, JWT / session secrets, and messaging adapter names. Failures abort with remediation text; warnings print but allow success.

Doctor does **not** probe Redis/SMTP connectivity.

## Host vs CommandTower responsibilities

| Concern | Owner |
|---------|--------|
| Author CT schema migrations | CommandTower |
| Install / run migrations | Host (via engine tasks + `db:migrate`) |
| Product configuration / secrets | Host initializer + ENV |
| Dual-author CT schema in the host | **Forbidden** |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `users already exists` on migrate | Database not empty / stale `schema.rb` load — migrate an empty DB, or dump schema after a clean migrate |
| Install copies nothing new | Already installed — expected idempotency |
| Missing tables after install | You installed but did not `db:migrate` |
| Doctor fails on JWT default | Set `config.jwt.hmac_secret` from a real secret |
| Accidental public engine mount | Use `SKIP_MOUNT=1` / `--skip-routes`, or mount at the path your product needs |

## Existing customized hosts

If the host already has a bespoke initializer and mount:

```bash
SKIP_CONFIGURE=1 bin/rails command_tower:install
# same as: bin/rails command_tower:install:migrations
bin/rails db:migrate
```

Do not run `rails g command_tower:configure` unless you intentionally want stock scaffolding.

## Test suite factories

Shared FactoryBot definitions ship with the gem. In the host test boot path:

```ruby
require "command_tower/testing"
CommandTower::Testing.install!
```

Then extend with `FactoryBot.modify` as needed. See [Testing with CommandTower](testing.md).
