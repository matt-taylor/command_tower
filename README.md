# CommandTower

CommandTower is a mountable **Rails engine** that provides shared platform capabilities for host applications: JWT authentication, RBAC authorization, account/Me surfaces, messaging HTTP (inbox, preferences, endpoints), admin announcements, and shared test factories.

Hosts mount the engine, configure secrets and product policy, and build product features on top—without re-implementing platform foundations.

The engine is opinionated and configurable. Architecture follows a stable layer map (workflows orchestrate; services implement capabilities). See [Architecture](docs/architecture.md).

## Quick start

```ruby
# Gemfile
gem "command_tower"
```

```bash
bundle install
bin/rails command_tower:install
bin/rails db:migrate
bin/rails command_tower:doctor
```

Full install, upgrade, configuration, and troubleshooting: [Initializing CommandTower](docs/initializing.md).

After install, complete RBAC, feature gates, and a Me smoke check: [Host integration guide](docs/host_integration_guide.md) (**start here for a new Rails host**).

## Architecture

```text
Controller / Job → Workflow → Shared Sequences / Services → Models & Clients
```

- Controllers are transport adapters (one workflow per action).
- Workflows orchestrate a business action.
- Services (including `CommandTower::ServiceBase`) implement one capability.

See [Architecture](docs/architecture.md) and [ServiceBase](app/services/command_tower/README.md).

## Documentation

| Guide | Purpose |
|-------|---------|
| [Host integration](docs/host_integration_guide.md) | **Start here** — step-by-step new Rails host path |
| [Upgrades](docs/upgrades/README.md) | Release upgrade summaries (see [0.10.0](docs/upgrades/0.10.0.md)) |
| [Initializing](docs/initializing.md) | Install, configure, migrate, doctor, upgrades |
| [Testing](docs/testing.md) | Shared FactoryBot / `CommandTower::Testing` |
| [Architecture](docs/architecture.md) | Layer map for hosts and contributors |
| [Controllers / routes](docs/controllers.md) | Engine route areas (index) |
| [API reference](docs/api_reference.md) | Endpoint catalog (detailed contracts) |
| [Extending](docs/extending.md) | Stable extension points / do-not-extend |
| [Models](docs/models.md) | `User`, `UserSecret`, reopening classes |
| [Authentication](docs/authentication.md) | JWT auth quick start |
| [Authorization](docs/authorization.md) | RBAC quick start |
| [Authentication & authorization guide](docs/authentication_authorization_guide.md) | Deep authn + RBAC |
| [Cookie authentication](docs/cookie_authentication_guide.md) | HttpOnly cookies, CORS, CSRF |
| [Sensitive changes](docs/sensitive_routes.md) | Verifier token / session invalidation |
| [Messaging](docs/messaging_integration_guide.md) | Current messaging surfaces |
| [Pagination](docs/pagination.md) | Pagination helpers |
| [ServiceBase](app/services/command_tower/README.md) | Service capability base |
| [Password reset workflow](docs/password_reset_workflow.md) | Forgot-password flow |
| [Change password workflow](docs/change_password_workflow.md) | Authenticated password change |
| [Email verification workflow](docs/email_verification_workflow.md) | Email verification flow |

## Installation and configuration

See [Initializing CommandTower](docs/initializing.md) for:

- `command_tower:install` / `install:migrations`
- Configure generator flags (`SKIP_CONFIGURE`, `SKIP_MOUNT`, `FORCE`)
- Schema ownership (**AD-SCH-01**)
- Secrets and doctor checks
- Existing customized hosts

## Testing

Shared factories for hosts:

```ruby
require "command_tower/testing"
CommandTower::Testing.install!
```

Details: [Testing with CommandTower](docs/testing.md).

Engine HTTP coverage lives primarily under `spec/requests/`. Residual journey coverage may remain under `spec/integration_test/`.

## Routes

Engine routes cover Auth, Me (profile, inbox, preferences, phone, Pushover), and Admin messaging announcements. Index: [Controllers](docs/controllers.md). Contracts: [API reference](docs/api_reference.md).

## Models

Core models such as `User` and `UserSecret` are available for hosts to use and reopen carefully. See [Models](docs/models.md).

## Authentication (JWT)

Authentication establishes identity (`401` when it fails).

- **Engine controllers** use `authenticate_request!` / `authorize_request!` (Authentication/Authorization boundaries) and return the application envelope.
- **Host controllers** may use provisional `before_action :authenticate_user!` (failure shapes can differ — see the deep guide).

- Quick start: [Authentication](docs/authentication.md)
- Deep guide: [Authentication & authorization](docs/authentication_authorization_guide.md)
- Web / SPA cookies: [Cookie authentication](docs/cookie_authentication_guide.md)

Cookie mode supports HttpOnly JWT cookies, SameSite, optional double-submit CSRF, and secure cookies in production.

## Authorization (RBAC)

Authorization establishes permission after authentication (`403` when it fails).

Engine defaults ship `owner` and `admin` (announcements). Hosts **must** supply `rbac_groups.yml` entities for Me/Auth surfaces (fail-closed). Host controllers may use provisional `authorize_user!` after `authenticate_user!`.

- Quick start: [Authorization](docs/authorization.md)
- Deep guide: [Authentication & authorization](docs/authentication_authorization_guide.md)

## Sensitive changes

JWT tokens embed a `verifier_token` bound to the user. Rotating the verifier invalidates outstanding sessions. See [Sensitive changes](docs/sensitive_routes.md).

## Messaging

Modern messaging surfaces: Me Inbox consume, Produce / ProduceMany emit, admin announcements. See [Messaging](docs/messaging_integration_guide.md).

## Pagination

Pagination helpers are available for controllers and services. See [Pagination](docs/pagination.md).

## Services

`CommandTower::ServiceBase` adds logging and argument validation for **service** classes under workflows. See [ServiceBase](app/services/command_tower/README.md).

## License

MIT — see [MIT-LICENSE](MIT-LICENSE).
