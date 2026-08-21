# Admin Workspace

The Admin Workspace is CommandTower-owned **backend** navigation metadata: one configuration registry, boot-validated composition with host tools, and a RBAC-filtered runtime manifest. It does **not** proxy Audit or Messaging APIs. It does **not** ship a frontend shell (4.6.3+) or Audit Explorer UI (4.7). Do **not** use `GET /admin/workspace` as a generic UI permission probe — use [Principal capabilities](principal_capabilities.md) (`GET /auth/principal-capabilities`) for possessed projectable ids.

## Register (configuration)

Registration is configuration (`class_composer`), the same pattern as `config.registry.audit`. There is no `CommandTower::Admin.register` plugin API.

CommandTower seeds platform tools. Hosts **add** tools. Hosts **cannot** redefine CommandTower-owned ids (`users`, `audit`, `messaging`). Duplicate ids and duplicate `route` values fail. There is no speculative `enabled` flag.

```ruby
CommandTower.configure do |config|
  config.registry.admin_workspace.tool :pickem_example do |tool|
    tool.label = "Example"
    tool.description = "Short launcher explanation of what this tool does."
    tool.route = "/admin/example"
    tool.group = :product
    tool.sort_order = 300
    tool.required_entity = :host_example_entity
    tool.icon = "cube"
  end
end
```

Lookup: `CommandTower.config.registry.admin_workspace.fetch(:audit)`.

| Field | Rules |
|-------|--------|
| id | DSL name; `/\A[a-z][a-z0-9_]*\z/`; public contract, not a controller class |
| owner | `:command_tower` (seeded) or `:host` (default) |
| label | required non-blank string |
| description | optional plain-text launcher blurb; stripped; empty allowed; **hard max 160** characters (intentional exception vs unbounded `label` — free-form presentation prose). Soft authoring target ≤100. No HTML/Markdown. |
| route | required frontend path `/\A\/admin(\/[a-z][a-z0-9_-]*)+\z/` (navigation metadata, not an engine API path) |
| group | required segment token; **open** set |
| sort_order | required Integer |
| required_entity | required RBAC entity name; must exist in the composed graph after `Authorization.default_defined!` |
| icon | optional segment token or nil |

| `scope_required` | optional Boolean (default false); when true, tool APIs require host scope transport |
| `scope_parameter` | required when `scope_required`; query param key (e.g. `partition`) |
| `scope_label` | required when `scope_required`; presentation label for FE selector (e.g. `"Partition"`) |

Validate at `validate_definition!`: when `scope_required`, require non-empty `scope_parameter` + `scope_label`.

Hosts configure scope behavior on `CommandTower.config.admin_scope` (see [Resource scoping](#resource-scoping)). CT-owned tools may be extended via `configure_tool(:users)` / `configure_tool(:audit)` in host boot — do not redefine tool ids.

## Resource scoping

Optional **host-defined resource scoping** narrows Admin tool data (Users, Audit, …) after RBAC. CommandTower remains **domain-blind** — it does not know League, Season, or tenant semantics.

```ruby
CommandTower.configure do |config|
  config.registry.admin_workspace.configure_tool(:users) do |tool|
    tool.scope_required = true
    tool.scope_parameter = "partition"
    tool.scope_label = "Partition"
  end

  config.admin_scope.register(:users) do |registration|
    registration.options = ->(principal:) { [CommandTower::AdminScope::ScopeOption.new(value: "a", label: "A")] }
    registration.validate = ->(value:, principal:) { true }
    registration.availability = ->(principal:) { { enabled: true, reason: nil } }
    registration.narrow_users = ->(relation:, scope_value:, principal:, tool_id:) { relation }
    registration.narrow_audit = ->(relation:, scope_value:, principal:, tool_id:) { relation }
    registration.affected_users_in_scope = ->(scope_value:, principal:, tool_id:) { [] }
  end
end
```

| Hook | Purpose |
|------|---------|
| `options` | Eager scope choices for manifest (`scopeOptions`) |
| `availability` | `{ enabled:, reason: }` — disabled tools render non-navigable in FE |
| `validate` | Authorize requested scope value; fail closed → **403** |
| `narrow_users` | SQL narrowing for Users list/show |
| `narrow_audit` | SQL narrowing for host-scoped audit rows |
| `affected_users_in_scope` | User ids for eligible **global** audit events in scoped admin views |

**HTTP disclosure policy:** missing/malformed/unauthorized scope → **403**; authorized scope + resource absent from narrowed relation (nonexistent **or** out of scope) → **404** (indistinguishable).

Unscoped tools (`scope_required: false`, default) behave exactly as before — no scope query param, no `admin_scope` registration required.

Synthetic proof lives in `rails_app` (`FoundationProof::AdminScope`); Pick'em League adoption is Phase 7 only.

## Seeded CommandTower tools

These routes are **frontend navigation targets**. Shared Admin shell consumes them; capability APIs remain independently authorized.

| id | label | description | route | group | sort_order | required_entity | icon |
|----|-------|-------------|-------|-------|------------|-----------------|------|
| `users` | Users | Find and inspect platform user accounts. | `/admin/users` | `operations` | 50 | `admin_users` | `users` |
| `audit` | Audit | Browse account and administrative audit history. | `/admin/audit` | `operations` | 100 | `admin_audit_events` | `history` |
| `messaging` | Messaging | Manage platform announcements and administrative messaging. | `/admin/messaging` | `messaging` | 200 | `admin_messaging_announcements` | `megaphone` |

RBAC CRUD, health, and Pick'em product tools are **not** seeded. Impersonation is a session primitive (`POST /admin/users/:id/impersonation-sessions`), not an Admin Workspace tool.

## Boot validation

1. Host `CommandTower.configure` registers tools (mutable).
2. `after_initialize` — `audit.finalize!`, `admin_workspace.finalize!`, and `principal_capabilities.finalize!`, then freeze config (skipped in test). Stage 1 checks ids, ownership, and typed fields.
3. `to_prepare` — `Authorization.default_defined!`, then `admin_workspace.validate_required_entities!` and `principal_capabilities.validate_required_entities!`. Stage 2 requires every `required_entity` to exist in `Entity.entities`. RBAC is not available at `after_initialize`.

The same db/install/doctor rake skip paths as audit apply.

## Runtime HTTP

`GET /admin/workspace` (engine-relative; hosts that mount at `/api` use `GET /api/admin/workspace`).

- Authn + authz: entity `admin_workspace` (`WorkspaceController#show`). Hosts must **explicitly grant** that entity to operational roles. `owner` already has `entities: true`. Members without the entity receive **403**.
- One controller action → `Workflows::Admin::Workspace::ManifestWorkflow` (`retry_strategy :none`) → `Services::Admin::Workspace::Manifest` → `ManifestSerializer`.
- Include a tool when any of `user.roles` has `Role#allow_everything` **or** includes an entity whose name equals `required_entity`. Do not filter with `role == "admin"`.
- Host tools appear for `owner` and for **host-owned roles** that grant the host entity. Operational Admin roles are host policy; CommandTower does not ship an accumulating `admin` role.
- Order: `group` → `sort_order` → `id`.
- Envelope `data` (no pagination `meta`): `{ tools: [{ id, label, description, route, group, sortOrder, icon, scope?, scopeOptions?, availability? }] }`. Omit `owner`, `required_entity`, and Ruby classes. `icon` may be `null`. `description` is presentation metadata only and does not affect authorization.

When `scope.required` is true, manifest also includes:

| Field | Shape |
|-------|--------|
| `scope` | `{ required, parameter, label }` |
| `scopeOptions` | `[{ value, label }]` when `availability.enabled` |
| `availability` | `{ enabled, reason }` — `reason` when disabled |

Scope options are **eager** per principal on manifest fetch (no lazy scope endpoint in 5.4).

Capability APIs (`GET /admin/users`, `GET /admin/audit-events`, `POST /admin/messaging/announcements`) remain independently authorized. There is no generic `POST /admin/tools/:id/run`.

While an impersonation overlay is active, `GET /admin/workspace` remains allowed and **disables every projected tool** (`availability.enabled: false`, reason `Admin tools are unavailable while impersonating a user.`). All other `/admin/*` endpoints return **418** `admin_unavailable_during_impersonation`.

## Least privilege

CommandTower owns the Admin **entities**. Hosts compose roles such as:

```yaml
audit_operator:
  entities:
    - admin_workspace
    - admin_audit_events

messaging_operator:
  entities:
    - admin_workspace
    - admin_messaging_announcements
```

A host may deliberately define a broad `admin` role that grants many Admin entities — that is host policy, not a CommandTower default. Tool visibility follows granted entities, never role names.

## `/me` vs the manifest vs principal capabilities

`GET /me` remains account self-service flags, `roles`, and existing capabilities. Admin tool **discovery** is **`GET /admin/workspace` only**. Frontend-safe **possession** of projectable Admin (and host) capabilities is **`GET /auth/principal-capabilities`**. Do not copy the tool list onto `/me`, and do not treat the workspace manifest as a permission probe.

## Related

- [API reference](api_reference.md#admin-workspace)
- [Principal capabilities](principal_capabilities.md)
- [Authorization](authorization.md)
- [Audit](audit.md)
- [Messaging](messaging_integration_guide.md)
