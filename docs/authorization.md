# Authorization (RBAC)

Authorization establishes **permission** after authentication. Failed authorization returns `403`.

Host `rbac_groups.yml` is a **required integration step** (Step 4) — see [Host integration](host_integration_guide.md#step-4--host-rbac-required). Without it, authenticated Me/Auth calls fail closed.

## Quick usage (host provisional)

```ruby
# Order matters: authorize depends on current_user from authentication
before_action :authenticate_user!
before_action :authorize_user!
```

Engine controllers use `authorize_request!` instead (AuthorizationBoundary) and return the application envelope on failure.

## Roles and host mapping

Engine defaults in `lib/command_tower/authorization/default.yml`:

- `owner` — full access (`entities: true`)
- `admin` — `admin_messaging_announcements` only

Hosts **must** map Me/Auth controller actions in host YAML (`CommandTower.config.authorization.rbac_group_path`, default `config/rbac_groups.yml`) or authorization fails closed. See dummy host `rails_app/config/rbac_groups.yml` (`member` entities).

## Where to go next

| Need | Guide |
|------|-------|
| Full RBAC entities, roles, failure shapes | [Authentication & authorization guide](authentication_authorization_guide.md) |
| Authentication | [Authentication](authentication.md) |
| Install / config | [Initializing](initializing.md) |

Back to [README](../README.md).
