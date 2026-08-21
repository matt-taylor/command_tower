# Eventing

CommandTower publishes internal events on **one** Rails-native network: `ActiveSupport::Notifications`. Hosts and platform code do not invent a second bus.

Logging is a **consumer** of that network. CommandTower supplies structured Hash fields to `Rails.logger`. The host Rails logger/formatter/tagged/broadcast configuration owns the final representation. CommandTower does not JSON-encode log lines.

**Event emission is exhaustive; log materialization is selective.** Lifecycle started/completed pairs always publish. **Workflow** completed success/deferred logs to Rails `info` by default (`ApplicationWorkflow` declares `log_lifecycle!`). **Service** completed success stays quiet unless the service class opts in. `started` never materializes. Envelope `log_lifecycle` means “success may be materialized,” not “emit only when true.” Subscribers must not `const_get(subject)`.

Audit persistence is a **raising** subscriber on `command_tower.audit.*` (not on lifecycle, and not the logging subscriber). **Audit authoring** (`audit(...)`, registered policy, structured emission) is documented in [Audit](audit.md).

## Grammar

Instrument names are the subscription keys:

```text
command_tower.<category>.<name...>
```

- `command_tower` is the platform prefix. Hosts do **not** prepend it themselves.
- `category` is one token: `\A[a-z][a-z0-9_]*\z`. Categories are **extensible**, not a closed enum.
- `name` is one or more tokens of the same shape, joined by `.`.

Do **not** publish a generic `command_tower.event` name and dispatch on `payload[:type]`.

Do **not** use `ActiveSupport::Subscriber#attach_to` as the taxonomy driver. That convention is reversed `event.namespace` (for example `sql.active_record`). CommandTower names are `command_tower.<category>.<name...>`. Subscribe with the full string or a prefix regexp.

### Lifecycle (automatic)

| Instrument name |
|-----------------|
| `command_tower.lifecycle.workflow.started` |
| `command_tower.lifecycle.workflow.completed` |
| `command_tower.lifecycle.service.started` |
| `command_tower.lifecycle.service.completed` |

Every `ApplicationWorkflow` `.call` / `call_from_job` invocation and every `ServiceBase` Interactor invocation emits one started/completed pair. Nested workflow→service shares `execution_uuid` and emits four events (two pairs).

### Semantic (deliberate)

```text
command_tower.<category>.<name...>
```

Example: `command_tower.audit.wager_transition` via **registered** `audit(:wager_transition, ...)` — see [Audit](audit.md). Generic scalar `publish_event` remains available for non-audit categories; nested audit `changes` require `audit(...)` / `Events.publish_audit`.

```ruby
publish_event(category: :messaging, name: :welcome_produce_failed, payload: { code: "x" })
```

`publish_event` is on `CommandTower::Execution::ContextAccess` (workflows and services inherit it). It delegates to `CommandTower::Events.publish`. Do not include a separate Eventing module.

## Subscribe

Rails 8.1 Fanout matches the **full instrument string**.

Exact:

```ruby
ActiveSupport::Notifications.subscribe("command_tower.lifecycle.workflow.completed") { |*args| }
```

Broad (lifecycle category):

```ruby
ActiveSupport::Notifications.subscribe(/\Acommand_tower\.lifecycle(?:\.|\z)/) { |*args| }
```

## Envelope

Payload is a frozen Hash of scalars (and frozen arrays of scalars). Never `CommandTower::Current`, User, request, AuthContext, JWT, cookies, or exception objects.

| Field | When |
|-------|------|
| `event_uuid` | every event (new UUID at publish; **not** `execution_uuid`) |
| `subject` | class name string |
| `layer` | `:workflow` / `:service` (lifecycle only) |
| `execution_uuid`, `correlation_id`, `request_id`, `causation_id`, `source` | Execution Context snapshot |
| `user_id`, `effective_user_id`, `originating_administrator_id`, `impersonation_active` | snapshot |
| `outcome` | completed only: `:success` / `:deferred` / `:failure` / `:error` |
| `duration_ms` | completed only (monotonic clock from matching started) |
| `error_class`, `error_codes` | completed failure/error; codes only, no messages/PII |
| caller keys | semantic publish only; unsafe objects are dropped |

`event_uuid` ≠ `execution_uuid`. There is no parent/child event graph. Nested work shares `execution_uuid` only.

The snapshot is taken at publish time and is frozen against later `Current` mutation.

## Publisher

```ruby
CommandTower::Events.publish(category:, name:, payload: {}, subject: nil, layer: nil)
CommandTower::Events.snapshot
```

`publish` builds the instrument name, merges snapshot + `event_uuid` + sanitized caller payload, then calls `ActiveSupport::Notifications.instrument` **without a block**. Business work is **not** yielded to `instrument`.

## Subscriber failure (Rails-native)

CommandTower uses ASN as a **synchronous** event network. `Events.publish` does **not** wrap `instrument` in `rescue StandardError`.

> CommandTower preserves Rails-native synchronous `ActiveSupport::Notifications` publication semantics. Subscriber failure policy belongs to the subscriber/capability consuming the event. Best-effort consumers must protect their own failure boundary. Correctness-sensitive subscriber semantics are defined by the owning capability.

The generic publisher does **not** impose either policy.

| Consumer | Policy owner |
|----------|----------------|
| Logging subscriber | **This slice** — best-effort; rescues materialization failures |
| Metrics subscriber | future (likely self-protecting) |
| Audit subscriber | later phase (may be correctness-sensitive) |
| Other semantic subscribers | owning capability |

The logging subscriber (`CommandTower::Logging::Subscriber` < `ActiveSupport::LogSubscriber`) subscribes with prefix regexes (not `attach_to`) to:

- `command_tower.lifecycle.*`
- `command_tower.log.*`
- `command_tower.messaging.*`

It does **not** subscribe to `audit` or `metric`. It calls `Rails.logger` with a Hash. Host formatters decide text vs JSON vs tagged output.

### Lifecycle Rails logs

`ApplicationWorkflow` declares `log_lifecycle!`, so workflow **completed** success/deferred materializes at `info` by default. Services stay quiet unless they opt in. Use `disable_lifecycle_logging!` on a workflow subclass to suppress its completed success line.

```ruby
class NoisyService < ApplicationService
  log_lifecycle!
end

class QuietWorkflow < ApplicationWorkflow
  disable_lifecycle_logging!
end
```

`lifecycle_loggable?` walks superclasses when unset. `log_lifecycle:` is passed into `Events.around_execution` as a **boolean scalar**. `started` is never materialized.

### Severity and materialization

| Event | Materialize? | Level when materialized |
|-------|----------------|-------------------------|
| lifecycle started | **no** (even with opt-in — completed has outcome/duration) | — |
| lifecycle completed success / deferred | only if `payload[:log_lifecycle]` | `info` |
| lifecycle completed failure | **always** | payload `log_level` or `:info` |
| lifecycle completed error | **always** | `error` |
| `command_tower.log.<level>` | **always** | that level |
| `command_tower.messaging.*` | unchanged (3.3) | payload `log_level` or `:info` |

Authorization (`Authorize::Validate`) success diagnostics (“No Authorization required”, “User Roles”, per-role Authorized/Reason) publish `command_tower.log.debug`. Denial publishes `command_tower.log.warn`.

### Events are comprehensive. Logs are projections.

ASN payloads remain full Execution Context snapshots (`event_uuid`, nils, `layer`, `log_lifecycle`, duplicate identity fields). The logging subscriber **projects** a new Hash for `Rails.logger`. It does not mutate the canonical payload and does not define the event contract.

**Core log fields** (when present): `event`, `subject`, `execution_uuid`, `correlation_id`, lifecycle `outcome`, `duration_ms`.

**Conditional:** `user_id` when present; `request_id` when present and different from `correlation_id`; `source` when not `:http`; `causation_id` / `originating_administrator_id` when present; `effective_user_id` when different from `user_id`; `impersonation_active` only when `true`; `error_class` / `error_codes` when present.

**Omitted from ordinary logs:** nils; `event_uuid`; `layer`; `log_lifecycle`; payload `log_level` (Rails severity already carries level); default `impersonation_active: false`; HTTP `source`.

Semantic events (`command_tower.messaging.*`, `command_tower.log.*`) keep the same common context plus remaining safe scalar fields (`message`, `channel`, `provider`, `attempt`, …). Host formatters still own JSON / tags / LGTM representation; CommandTower does not promise a Rails JSON schema.

`ApplicationError#log_level` is copied onto completed failure events as a scalar.

`log_debug` / `log_info` / `log_warn` / `log_error` publish `command_tower.log.*`. Messaging OperationLoggers publish `command_tower.messaging.*`. Delivery LogAdapters remain a **transport** (`Rails.logger.info` of a send), not observation.

Direct `Rails.logger` remains allowed for JWT decode/authenticate, boot/lib/controllers, and LogAdapters. Workflows/services must not write lifecycle observation directly.

A raising **logging** subscriber does not fail the business action. A raising **non-logging** test/audit subscriber still surfaces through `Events.publish`.

Emission and consumption remain separate: logger silence / level skips **materialization**, never ASN publication.

Architecture specs guard these seams: one `CommandTower::Current`, kernel-owned lifecycle, `Events.publish` as the ASN publisher, curated log projection, and an explicit `Rails.logger` allowlist in JWT/LogAdapter infrastructure.

## Kernel behavior (when subscribers do not raise)

- `ApplicationWorkflow.call`: unexpected `StandardError` still becomes InternalError **after** completed `outcome: :error`. `validate_retry_strategy!` stays outside instrumentation.
- `call_from_job` / `invoke_for_job`: still **re-raise** after completed `outcome: :error`.
- Services: Interactor success → `:success`; `Interactor::Failure` → `:failure` then re-raise; unexpected exception → `:error` then re-raise. Services have no deferred outcome.

Do not wrap instance `#call` in addition to class entry (duplicate pairs). Do not also wrap `ApplicationService.call` (the Interactor `around` is the service pair).
