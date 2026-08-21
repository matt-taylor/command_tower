# Principal capabilities

Authenticated **frontend-projectable** capability ids for the current principal. Projection is `effective RBAC entity grants ∩ curated registry` — never role/group names, and never an auto-dump of `Entity.entities`.

```text
RBAC groups → entity grants → curated projectable registry
  → possessed principalCapabilities → shared FE gating (4.6.2+)
```

CommandTower owns which CT entities are frontend-projectable. Hosts own who receives those entities through RBAC group composition. Hosts register **host-owned** projectables only; they do **not** re-register or redefine CT capability ids.

## Register (configuration)

```ruby
CommandTower.configure do |config|
  # Default 1:1 — id and required_entity share the same name
  config.registry.principal_capabilities.capability :admin_workspace

  # Host additive (example) — override required_entity when names differ
  config.registry.principal_capabilities.capability :manage_wagers do |capability|
    capability.required_entity = :pickem_admin_wagers
  end
end
```

| Field | Rules |
|-------|--------|
| id | DSL name; public contract |
| required_entity | RBAC entity name; defaults to id when omitted; must exist after RBAC composition |
| owner | `:command_tower` (seeded) or `:host` (host registration) |

Lookup: `CommandTower.config.registry.principal_capabilities.fetch(:admin_workspace)`.

## Seeded CommandTower catalog (4.6.1 + 4.7.1 + 6.3)

| id / required_entity | Why projectable |
|----------------------|-----------------|
| `admin_workspace` | Gate Admin Workspace affordances without probing `/admin/workspace` |
| `admin_users` | Gate Admin Users Collection/detail presentation |
| `admin_users_update` | Gate Admin Users identity mutations (name, username, email, email validation) |
| `admin_rbac_assignments` | Gate Admin Users role assignment (assignable catalog + PATCH roles) |
| `admin_audit_events` | Gate Audit Admin affordances and deep links outside the workspace manifest |
| `admin_messaging_announcements` | Gate Messaging Admin affordances outside the manifest |
| `admin_impersonation` | Gate Impersonate affordances (5.6 composition). Possession does not start a session by itself. |
| `me_audit_events` | Gate Account **Activity** / self-audit Explorer presentation (4.7.1). Hosts own who receives the entity. |

Me/Auth route gates (`session`, `me`, …) and unimplemented Admin entities are **not** seeded. Adding a new CT RBAC entity later requires an explicit slice decision to also register a principal capability.

## Boot validation

1. Host `CommandTower.configure` may register additive capabilities (mutable).
2. `after_initialize` — `principal_capabilities.finalize!` with audit / admin_workspace, then freeze (skipped in test).
3. `to_prepare` — after RBAC, `validate_required_entities!(Entity.entities)`.

## Runtime HTTP

`GET /auth/principal-capabilities` (engine-relative; hosts mounting at `/api` use `GET /api/auth/principal-capabilities`).

- Authn + authz: entity `principal_capabilities` (`PrincipalCapabilitiesController#show`). Grant to host `member` (and operators that need the call) like other Me/Auth surfaces.
- Controller → `Workflows::Auth::PrincipalCapabilities::ShowWorkflow` (`retry_strategy :none`) → `Services::Auth::PrincipalCapabilities::Project` → `PrincipalCapabilitiesSerializer`.
- Service: if any role has `allow_everything`, return **all** registered projectable ids; else include definitions whose `required_entity` is granted. Unique + sorted. No role-name checks.
- Envelope `data`: `{ principalCapabilities: string[] }` — possessed ids only.

| Persona (typical host composition) | Example `principalCapabilities` |
|------------------------------------|---------------------------------|
| guest | **401** |
| email verification required | **412** |
| `member` (host grants `me_audit_events`) | `me_audit_events` |
| `member` (host withholds `me_audit_events`) | `[]` |
| `audit_operator` | `admin_audit_events`, `admin_workspace` |
| `messaging_operator` | `admin_messaging_announcements`, `admin_workspace` |
| host `admin` / `operations_admin` | CT Admin seeds (not necessarily `me_audit_events`) |
| `owner` | all **registered** ids (CT + host additive) |

## Naming collisions (different concepts)

| Name | Meaning |
|------|---------|
| `principalCapabilities` / this registry | Runtime possessed, frontend-projectable RBAC-backed facts |
| `/me` `capabilities` | Account self-service flags — **not** this projection |
| HostConfig / build-time `capabilities` | Compile-time product modules — **not** this projection |
| RBAC group / role names | Host privilege composition — **never** the FE gating contract |

## Related

- [API reference](api_reference.md#get-authprincipal-capabilities)
- [Authorization](authorization.md)
- [Admin Workspace](admin_workspace.md) — tool manifest only; not a UI permission probe
- [Host integration](host_integration_guide.md)
