# Audit (authoring contract)

Explicit semantic audit is a first-class CommandTower capability on workflows and services. It is **not** inferred from lifecycle completion, ActiveRecord dirty tracking, routes, or model callbacks.

A workflow or service may emit **zero, one, or many** audit facts. **Workflows are the preferred publication boundary.** Ownership follows the **semantic fact**, not whichever layer executes SQL. Do not emit the same fact from both a workflow and a service.

Registered `command_tower.audit.*` facts persist into **one** CommandTower ledger (`command_tower_audit_events` / `CommandTower::Audit::Event`) through a **synchronous, raising** subscriber.

**Audit persistence is transaction-aware, not transaction-requiring.** `audit(...)` does not create or require a business transaction. If an ActiveRecord transaction is already active, the INSERT joins it and shares commit/rollback. If none is active, the fact persists as a standalone synchronous write. Persistence failure raises: inside a transaction that can roll back the surrounding operation; outside one, only the audit write fails loudly.

Use a transaction when the **business operation itself** requires atomicity. Emit `audit(...)` while that transaction is active when the audit fact must share the operation’s commit/rollback boundary. Otherwise `audit(...)` may persist without an enclosing transaction. An auditable workflow is not automatically a transactional workflow.

Mutation-coupled facts (`role_assigned`, `password_changed`, `phone_verified`) commonly belong inside the mutation’s transaction. Standalone facts (`session_created`, `login_failed`, `session_cleared`, `announcement_produced`, `impersonation_started`, `impersonation_ended`) need not.

Logging remains a separate consumer. Hosts do not install their own audit subscriber; the engine attaches `CommandTower::Audit::Persistence::Subscriber` on boot. Sparse hosts get the table by running `command_tower:install:migrations` then `db:migrate`.

Rows are **append-only**. Application code must not `update` or `destroy` ledger rows. Workflows and services must not `Audit::Event.create!`; only the persistence subscriber writes.

Production publishers for the catalog below **are shipped**. Query APIs read `CommandTower::Audit::Event` through List + Project services; the raw row is not the HTTP contract. Admin Workspace **backend** manifest is shipped (`GET /admin/workspace`). Shared Audit Explorer UI is shipped. Filter-options projection is shipped.

Lifecycle vs audit vs logs: [Eventing](eventing.md).

## Register (configuration)

Registration is configuration (`class_composer`). There is no plugin `register(...)` API. CommandTower and hosts share **one** registry and **one** `command_tower.audit.*` namespace.

CommandTower-owned names are seeded by the engine. Hosts **add** names. Hosts **cannot** redefine CommandTower-owned definitions (boot/runtime fail-fast).

```ruby
CommandTower.configure do |config|
  config.registry.audit.event :wager_placed do |event|
    event.enabled = true
    event.user_history = true
    event.label = "Wager placed"
    event.tags = %w[pickem wager]
    event.sensitive_fields = []
    event.allowed_changes = %i[status]
    event.retention = :permanent # :permanent | :ninety_days | :one_year
    event.subject_required = true
    event.affected_user_required = true
  end
end
```

**Policy (registration) owns:** `enabled`, `enablement_configurable`, `user_history`, `label`, `tags`, `sensitive_fields`, `allowed_changes`, `retention`, subject/affected-user required flags, **`global_visible_in_host_scope`** (default false).

**Discovery tags** (`tags`) are presentation metadata used by consumers such as Audit Explorer to help operators find event types in filter-option selectors. Tags are normalized (lowercase, stripped, unique, deterministic). They do **not** affect authorization, event publication, ledger persistence, or server-side audit filtering — there is no `?tag=` ledger filter and tags are not stored on audit rows.

**Runtime `audit(...)` owns:** occurrence name, subject, affected user, `changes`, `metadata`, explicit `attribution_mode` when required, optional **`host_context:`** (`{ type:, identifier: }`), optional **`scope_class:`** (`global` \| `host` \| `legacy`).

Lookup: `CommandTower.config.registry.audit.fetch(:wager_placed)`.

Filter-option projection (scoped catalogs for Explorer):

```text
GET /me/audit-events/filter-options
GET /admin/audit-events/filter-options
```

Projects `{ eventNames: [{ value, label, tags }], subjectTypes: [{ value, label }], attributionModes: […] }` from the live registry. Me includes only `user_history` events and omits attribution modes. `subjectTypes` are unique sorted registry `subject_type` values (blank omitted). Options are not authorization.

CommandTower registration defines both the canonical contract **and** whether publication enablement may be configured. Core facts are mandatory (`enablement_configurable: false`). Hosts cannot disable them. Selected noisy facts (`session_created`, `session_cleared`, `login_failed`) are enablement-configurable. Hosts may change **only** `enabled` via `CommandTower.config.registry.audit.set_enabled!(:login_failed, true)` before `finalize!`. Hosts still cannot `event :session_created`.

```ruby
CommandTower.config.registry.audit.set_enabled!(:session_created, false)
CommandTower.config.registry.audit.set_enabled!(:login_failed, true)
```

## Catalog (CommandTower-owned)

| Event | Default enabled | Enablement configurable |
|-------|----------------:|------------------------:|
| `user_registered` | yes | no |
| `role_assigned` | yes | no |
| `password_changed` | yes | no |
| `email_verified` | yes | no |
| `phone_updated` | yes | no |
| `phone_cleared` | yes | no |
| `phone_verified` | yes | no |
| `announcement_produced` | yes | no |
| `impersonation_started` | yes | no |
| `impersonation_ended` | yes | no |
| `session_created` | yes | yes |
| `session_cleared` | no | yes |
| `login_failed` | no | yes |

Sensitive-field / user-history / retention stay on the **registry** for emit-time policy. At INSERT the persistence subscriber copies the **smallest historical snapshot**: `user_history`, `sensitive_fields`, and `retention`. Later registry changes must not unmask historical PII. Read APIs treat a change key as sensitive if it is in the **union** of the row snapshot and the current definition (current may be more restrictive; it cannot unmask). Account-history eligibility is **only** the snapshot `user_history` column. The snapshot does not include `enabled`, `allowed_changes`, or owner. There is no `visibility` column. Retention is stored and **not enforced** as a delete/filter yet.

Invalid names, duplicates, host overrides, and illegal policy (for example sensitive fields not in `allowed_changes`) raise `CommandTower::Audit::*` errors.

## `audit(...)`

Available via `CommandTower::Execution::ContextAccess` on `ApplicationWorkflow` and `ServiceBase`:

```ruby
audit(
  :user_email_changed,
  subject: user,
  affected_user: user,
  changes: { email: { from: old_email, to: new_email } },
  metadata: { reason: "user_request" },
  attribution_mode: nil,
  subject_label: nil
)
```

Callers do **not** build ASN strings and do **not** `Audit::Event.create!`.

Instrument name: `command_tower.audit.<registered_name>`.

### Changes

Shape: `{ attribute: { from:, to: } }`. Empty `changes: {}` is valid (for example `password_changed`). Keys must be ⊆ registered `allowed_changes`. Extra keys **raise**; they are not dropped.

Nested hashes are published through `CommandTower::Events.publish_audit`. Generic `Events.publish` / `sanitize_payload` still keep only scalars (and arrays of scalars). The ledger column is `change_set` because ActiveRecord reserves `changes` for dirty tracking.

### Disabled events

A registered event with `enabled = false` causes `audit(...)` to **return without emitting**. Disabled events therefore insert **no row**. Unregistered names still fail **before** persistence.

### Attribution

| Mode | When | Actor |
|------|------|--------|
| `impersonation` | `Current.impersonation_active` | `originating_administrator_id` |
| `admin_direct` | explicit keyword | `Current.user_id` |
| `system` | explicit, or no `Current.user_id` | `nil` |
| `self_service` | default when actor id equals affected user id | `Current.user_id` |

Do not infer `admin_direct` from routes or from id inequality. `Current.user_id` remains the **effective** user under impersonation.

Lifecycle events `impersonation_started` / `impersonation_ended` record the administrator as actor and the impersonated user as affected. Product mutations executed during an overlay use `attribution_mode: impersonation` automatically from Current.

### Fail-fast

Unregistered names, forbidden change keys, unsafe objects in `changes`/`metadata`, missing required subject/affected user, and invalid attribution **raise**. Malformed audit data is never silently discarded.

## Transaction-aware persistence

```text
Standalone audit
  audit(...)
  → INSERT

Transactional business operation
  BEGIN
    mutation
    audit(...)
  COMMIT
```

The outer `BEGIN` exists only when the **business operation** needs atomicity. Audit does not impose it.

## Audit publisher ownership

Workflows are the preferred owners of semantic audit facts because workflows represent canonical business orchestration. New audit publishers should be placed in the owning workflow when that can be done cleanly.

Typical shape:

```text
orchestrate service mutation
        ↓
receive meaningful result
        ↓
emit semantic audit fact
```

Services may emit audit facts when the service uniquely owns the mutation or moving publication upward would require artificial plumbing, result-contract distortion, or transaction gymnastics.

Existing service-owned audit publishers (Phase 4.3) remain supported. Consolidation toward workflow ownership is deferred platform cleanup, not a Phase 4 correctness requirement. Do not reshape service result contracts purely to satisfy audit placement without an explicit architecture decision.

Do not double-emit from workflow and service. Models, controllers, jobs, and callbacks remain inappropriate audit publishers.

## Reading audit history

The ledger is queryable over HTTP. Controllers stay transport-only. Workflows orchestrate; they do **not** query `Audit::Event`. `Services::Audit::Events::List` owns the relation. `Services::Audit::Events::Project` duplicates hashes and masks sensitive `change_set` from/to **before** serialization. Unmasked sensitive values never leave Project toward HTTP. Both user and admin projections mask. There is no unmask permission.

| Surface | Path | RBAC entity | Scope |
|---------|------|-------------|-------|
| User | `GET /me/audit-events` | `me_audit_events` | `affected_user_id == current_user.id` **and** snapshot `user_history == true`. Actor identity never grants visibility. The Me controller does not read a target user from params. |
| Admin | `GET /admin/audit-events` | `admin_audit_events` | Full ledger when unscoped. When tool is scoped: composite host-scoped + eligible global for in-scope users; **legacy excluded**. |
| User detail | `GET /me/audit-events/:id` | `me_audit_events` | Same Me scope as list. **404** when out of scope or missing. |
| Admin detail | `GET /admin/audit-events/:id` | `admin_audit_events` | Full ledger by id when unscoped. **404** when missing or out of scope (disclosure-safe). |

**Scope provenance columns:** `scope_class` (`global` \| `host` \| `legacy`), `host_context_type`, `host_context_identifier`. Pre-scope historical rows migrated to **`legacy`** — not bulk-labeled `global`. Legacy rows are **not** eligible for scoped-admin global inclusion.

Pagination matches Inbox: `limit` default **50** (unchanged), max **100**, `offset` default 0, `meta: { limit, offset, totalCount }`. Shared Audit Explorer FE always sends `limit` from Collection pageSize (default **25**). Order is `occurred_at DESC, id DESC`.

User filters: optional `eventName` (singular alias) or `eventNames[]` (exact `action` `IN`), `occurredAfter` / `occurredBefore` (ISO8601), `subjectType` (singular alias) or `subjectTypes[]` (`IN`). Admin adds `affectedUserId`, `actorUserId`, `originatingAdministratorId`, `attributionMode`. Invalid enums/IDs are 422. Free-text / metadata JSON search is **not** supported (deferred).

Masking applies to sensitive **change keys** only (union of row `sensitive_fields` and the current registry for that action if still registered). Metadata is **not** masked: there is no metadata sensitivity grammar today. Phone uses last-four style (`*******1212`); email uses `m***@example.com`; nil stays nil; unknown/malformed values are fully redacted, never raw.

Serializer fields (camelCase), from the projection hash only: `id`, `eventName`, `eventLabel` (optional registry label; may be empty), `occurredAt`, `attributionMode`, `actor.userId`, `affectedUser.userId`, `subject.{type,id,label}`, `impersonationActive`, `originatingAdministratorId`, `changes`, `metadata`. List and show share this serializer. Snapshot internals, `event_uuid`, and execution/correlation IDs are not exposed.

Shared FE product: `@commandtower/frontend/capabilities/audit` (`AuditExplorer` scopes `admin` \| `me`). Account Activity presentation is gated by principal capability `me_audit_events`; Admin Explorer by `admin_audit_events`. Backend RBAC remains authoritative. The Admin Workspace **manifest** (`GET /admin/workspace`) discovers tools; it is not a UI permission probe.
