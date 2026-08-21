# Extending CommandTower

How hosts customize and integrate with CommandTower **without forking platform internals**.

**New host?** Start with [Host integration](host_integration_guide.md).

Layer map: [architecture.md](architecture.md). Install/configure/migrate/doctor: [initializing.md](initializing.md). Testing API: [testing.md](testing.md). HTTP catalog: [api_reference.md](api_reference.md).

## What hosts should extend

| Stable Extension Point | Purpose |
|------------------------|---------|
| Routes | Additional host endpoints |
| Controllers | Product-specific HTTP |
| Workflows | Product orchestration |
| Services | Product business logic |
| `Communications::Produce` / `ProduceMany` | Sending messaging |
| `FactoryBot.modify` | Extend shared factories |
| Model reopen | Product associations / behavior |
| Initializers | Configuration, including `config.registry.audit.event`, `config.registry.admin_workspace.tool`, and `config.registry.principal_capabilities.capability` |
| Notification catalogs / channel policy | Host-owned messaging customization |

## Internal platform — do not extend

| Internal Platform | Do Not Extend |
|-------------------|---------------|
| ApplicationWorkflow | Framework / shared orchestration base |
| ServiceBase | Shared service framework |
| Serializers | Platform response shaping |
| Deserializers | Platform request trust boundary |
| Messaging execution pipeline | Handoff / execution / accept internals |
| RequestContext | Framework request context |
| JWT primitives | Token issue / validate plumbing |
| Internal framework plumbing | Envelope renderer, workflow base mechanics, etc. |

Hosts **use** these via documented public APIs and configuration. Do not subclass, reopen, or fork them as product customization.

## Generators and install flags

Full install narrative: [initializing.md](initializing.md).

| Surface | Notes |
|---------|--------|
| `bin/rails command_tower:install` | Migrations + optional configure |
| `SKIP_CONFIGURE=1` | Migrations only |
| `SKIP_MOUNT=1` | Initializer without mount |
| `FORCE=1` | Overwrite initializer |
| `rails g command_tower:configure` | `--skip-routes`, `--force` |

## Mounting and configuration

Mount `CommandTower::Engine` at the path your product needs. Configuration and secrets belong in the host initializer. Details: [initializing.md](initializing.md).

## Migrations

CommandTower authors CT-owned schema; hosts install via engine tasks (`command_tower:install:migrations` / `command_tower:install`) and run `db:migrate`. Do not dual-author CT schema in the host (**AD-SCH-01**). Details: [initializing.md](initializing.md).

## Testing API and factories

Primary SST: [testing.md](testing.md).

| API | Role |
|-----|------|
| `CommandTower::Testing.install!` | Preferred host entry (loads factories) |
| `CommandTower::Testing.load_factories!` | Factories only / advanced |
| `CommandTower::Testing.ensure_endpoint_secret!` | Test helper for endpoint ciphertext when env unset |
| `FactoryBot.modify` | Host extension of shared factories |

Shipped factory files (under the gem `spec/factories/`): `user`, `user_secret`, messaging factories, `entity`, `role`.

## RBAC on host controllers

Protect host controllers with `authenticate_user!` / `authorize_user!` (or modern Auth boundaries) and RBAC entities. See [authentication_authorization_guide.md](authentication_authorization_guide.md) and [api_reference.md](api_reference.md).

## Model reopen

Prefer services/workflows for new behavior. Reopen patterns: [models.md](models.md).

## Produce from product workflows

Product business events own **host** workflows that call:

- `CommandTower::Services::Messaging::Communications::Produce`
- `CommandTower::Services::Messaging::Communications::ProduceMany`

Do not create one Messaging workflow per message type. Do not call the messaging handoff/execution pipeline directly. Summary: [messaging_integration_guide.md](messaging_integration_guide.md).

## Blank-host checklist

1. Add gem → [initializing.md](initializing.md) quick start (`install`, `db:migrate`, `doctor`)
2. Configure secrets and feature flags in the host initializer
3. Mount the engine
4. Load factories in the host test boot path → [testing.md](testing.md)
5. Exercise shared surfaces via engine routes → [controllers.md](controllers.md) / [api_reference.md](api_reference.md)
6. Add product routes/controllers/workflows/services only in the **stable extension** columns above
7. Keep catalogs, channel policy, and adapter credentials host-owned

No DoubleFloor Me (or other product) source is required to use the platform.

## Execution Context

Greenfield hosts inherit CommandTower-owned execution-boundary bases so HTTP and jobs establish ambient context automatically:

```ruby
class ApplicationController < CommandTower::ApplicationController
end

class ApplicationJob < CommandTower::ApplicationJob
end
```

`CommandTower::Current` is the single `CurrentAttributes` bag (`execution_uuid`, `correlation_id`, `request_id`, `source`, identity scalars). Workflows and services **read** it (`execution_context`); they do not mint a new execution per call.

`CommandTower::Auth::RequestContext` remains the HTTP request/response JWT transport handle. It is not Execution Context.

Rake/console (and other non-HTTP/job entry points) wrap work with:

```ruby
CommandTower.with_execution(source: :rake) do
  # ...
end
```

Nested `with_execution` shares the outer context. Do not wrap `db:migrate` or doctor.

If a host **cannot** change `ApplicationController` / `ApplicationJob` superclasses, include `CommandTower::Execution::HttpBoundary` / `CommandTower::Execution::JobBoundary` as a compatibility escape hatch. Do not include those modules into every `ActionController` or `ActiveJob::Base`.

Automatic workflow/service lifecycle notifications are emitted by CommandTower kernels. Logging is a subscriber: emission is exhaustive; materialization is selective; log records are curated projections. The host owns format. See [Eventing](eventing.md).

## Related

- [Eventing](eventing.md)
- [Architecture](architecture.md)
- [Controllers](controllers.md)
- [Sensitive changes](sensitive_routes.md)
- Workflow guides: [password reset](password_reset_workflow.md), [change password](change_password_workflow.md), [email verification](email_verification_workflow.md)
