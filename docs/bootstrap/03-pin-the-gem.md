# 03 — Pin the CommandTower gem

## Purpose

Depend on released CommandTower from **RubyGems** (or a git tag). Path pins are maintainer Local mode, not the committed default for a new host.

## Prerequisites

- [`02-create-the-rails-app.md`](02-create-the-rails-app.md): `make bundle` works
- You know the CommandTower version (or git tag) this host should adopt

## Files the host edits

`Gemfile` — add:

```ruby
gem "command_tower"
```

Pin when you need a floor:

```ruby
gem "command_tower", "~> X.Y"
```

Git tag (only if your org does not publish the gem to the RubyGems source the host uses):

```ruby
gem "command_tower", git: "https://github.com/<org>/command_tower.git", tag: "vX.Y.Z"
```

**Path pins** (`path: "../command_tower"`) are for engine maintainers iterating locally. They are not the default a new product host commits. If you use a path pin in a workspace, do not document it as the production pin.

## Procedure

1. Add the gem line.
2. Refresh lockfile **in the container**:

```bash
make bundle
```

3. Rebuild if the image copies `Gemfile` / `Gemfile.lock` at build time:

```bash
make build
```

Do not run `bundle install` on the Mac.

## Stop

`Gemfile.lock` lists `command_tower`. `make bundle` succeeds. Next: [`04-secrets-and-env.md`](04-secrets-and-env.md).
