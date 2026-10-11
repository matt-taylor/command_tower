# 02 — Create the Rails app

## Purpose

Generate a Rails **8.1 API** application **inside the Compose image**. The host OS never receives a `rails` binary.

## Prerequisites

- [`01-docker-make-compose.md`](01-docker-make-compose.md) complete: `make build` works
- Working directory is the host repository (already contains Dockerfile / Compose / Makefile)

## Files this step creates (inside the container, onto the mount)

Rails’ `rails new .` writes `Gemfile`, `config/`, `app/`, `bin/`, and the rest of a standard API app into the current directory.

`--force` is required because Dockerfile, Compose, and Makefile already exist.

## Procedure

```bash
make rails-new
```

That target (from step 01) runs in the `api` service:

```text
gem install rails -v "~> 8.1.0" --no-document
rails new . --api --database=mysql --skip-git --force
```

Both commands run **in the container**. `--skip-git` avoids nesting a repo; you already have Git on the host. `--database=mysql` matches MariaDB via the `mysql2` adapter.

If `rails new` overwrites `Dockerfile`, `docker-compose.yml`, or `Makefile`, **restore the files from step 01**. Rails generators are not the source of the host toolchain. Confirm `command:` / `CMD` still bind `-b 0.0.0.0`.

Then add host gems CommandTower does not replace. In `Gemfile` (keep `mysql2` and `puma` from `rails new`):

```ruby
gem "rack-cors"
```

`command_tower` (step 03) already depends on `redis`. You do not need a second Redis gem unless the host uses Redis for its own cache.

Set `config/database.yml` so development points at the `db` service, not `localhost` on the Mac:

```yaml
development:
  adapter: mysql2
  encoding: utf8mb4
  collation: utf8mb4_unicode_ci
  url: <%= ENV.fetch("DATABASE_URL") %>
```

Leave test until you add a test database; `db:prepare` can create it later.

Local mail for verify/reset codes (Compose-mounted `tmp/` is visible on the Mac):

```ruby
# config/environments/development.rb
config.action_mailer.perform_deliveries = true
config.action_mailer.delivery_method = :file
config.action_mailer.file_settings = { location: Rails.root.join("tmp/mails") }
```

Then:

```bash
make build
make bundle
```

Do not run `rails new` on the Mac. Do not `brew install ruby` to make this step “easier.”

## Stop

`Gemfile` exists, `bin/rails` exists **in the repo** (executed only via `make rails`). Dockerfile/Compose from step 01 are still the operator toolchain. `make bundle` succeeds. Next: [`03-pin-the-gem.md`](03-pin-the-gem.md).
