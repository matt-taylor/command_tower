# Testing with CommandTower

CommandTower ships FactoryBot definitions for engine-owned models. Hosts load
them explicitly in the test suite — there is no production Railtie and
FactoryBot is not a runtime gem dependency.

Back to [README](../README.md). See also [Initializing](initializing.md).

## Setup

```ruby
# spec/rails_helper.rb (after Rails is loaded)
require "command_tower/testing"

CommandTower::Testing.install! # preferred
# CommandTower::Testing.load_factories! # factories-only / advanced
```

Call `install!` **before** any host `FactoryBot.modify` blocks so shared
factories exist when you extend them.

## Extending factories

Hosts must not redefine CommandTower base factories. Use `FactoryBot.modify`:

```ruby
FactoryBot.modify do
  factory :user do
    roles { ["member"] }

    trait :operator do
      roles { %w[member operator] }
    end
  end
end
```

## Packaging and evolution

Factory files live under `spec/factories/**` inside the gem and are included in
the gemspec. Adding or changing a shared factory is a normal CommandTower gem
bump — hosts pick it up on upgrade.

`CommandTower::Testing.load_factories!` is idempotent (safe to call more than
once). It loads each factory file under `CommandTower::Engine.root/spec/factories`
explicitly; it does not append to global `FactoryBot.definition_file_paths`.

## Responsibilities

| Owner | Responsibility |
|-------|----------------|
| CommandTower | Base factories for CT-owned models; Testing API; packaging |
| Host | `install!` in the test boot path; product traits via `FactoryBot.modify` |

## Factory invariant

Base factories construct **persistent model state only**. They must not invoke
Services, Workflows, ApplicationWorkflows, or external adapters. Endpoint
ciphertext uses `SecretBox` / `Fingerprinter` (crypto helpers).

For endpoint factories in environments where
`COMMAND_TOWER_MESSAGING_ENDPOINT_SECRET` is unset, you may call:

```ruby
CommandTower::Testing.ensure_endpoint_secret!
```

(SecretBox already falls back to a non-production test secret outside production.)

## Contributors vs hosts

This guide is the **host Testing API**. Contributors working inside the CommandTower
repository also follow workspace test standards (`.cursor/rules/testing.mdc`) and
architecture guards under `spec/architecture/`.
