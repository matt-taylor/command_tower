# Home Notices

Home Notices let a host show a notice to a signed-in user on the home surface. The host declares each notice as a class. The platform owns pacing, windows, selection and audit. This page covers **authoring** and the boot checks. Selection is covered below. Later behavior (endpoints, delivery, kill switch) is added here as it ships.

Home Notices are off by default. With `config.home_notices.enabled = false` the catalog is not loaded.

## Two kinds

| Kind | Base class | Use it for | Source of truth |
|---|---|---|---|
| Campaign | `CommandTower::HomeNotices::Campaign` | A notice the host derives from application state ("make your picks") | The host's `show?` and `period_key`; the platform materializes one row per user per period |
| Delivery | `CommandTower::HomeNotices::Delivery` | A notice a host workflow pushes to one user ("class canceled") | A persisted row per user |

Subclass `Campaign` or `Delivery`. Never subclass `Notice` directly. Macros that belong to one kind are rejected on the other at boot.

## Macros

Macros set a value when given an argument and read it when called bare. Subclasses inherit them.

| Macro | Kind | Meaning |
|---|---|---|
| `key "host.name"` | both | Required, unique. Lowercase letters, digits and `_`, with at least one `.`. The `ct.` prefix is reserved for the platform |
| `severity :blocking` or `:dismissible` | both | Required |
| `priority 50` | both | Required Integer; higher wins |
| `blocking_reason "..."` | both | Required for `:blocking`, at least 20 characters. Records why the notice may interrupt the user |
| `window starts_at:, ends_at:` | both | Optional absolute UTC window. Either bound may be nil. `starts_at` must be before `ends_at` |
| `impressions max:, cooldown:` | Campaign | Pacing. Required for a dismissible campaign |
| `period_key { \|user:, context:\| ... }` | Campaign | Identity of the current period. Impressions and acknowledgement reset when it changes |
| `composer :message` | Delivery | Links the delivery to a Messaging communication. A linked delivery needs no `show?` or `compose` |

## Instance methods

```ruby
def show?(user:, context:, notice:)  # whether the notice applies now; no network I/O
def compose(builder, user:, context:, notice:)  # builds the content on the document builder
```

- `notice` is a read-only `NoticeRecord`, or `nil` for a campaign that has no row yet.
- `context` is a `CommandTower::HomeNotices::Context` with `now`, `time_zone`, `app_version`, `platform`, `ui_catalog`, `client_compatibility` and `impersonating`.
- Both methods must be pure. The class holds no per-user state.

## Example

```ruby
class MakeYourPicks < CommandTower::HomeNotices::Campaign
  key        "pickem.make_your_picks"
  severity   :dismissible
  priority   50
  impressions max: 4, cooldown: 12.hours

  def show?(user:, context:, notice:)
    PicksOpen.for(user:)
  end

  def compose(builder, user:, context:, notice:)
    # build content on the builder
  end
end
```

Working samples (fictional values) live in the engine's dummy app: `rails_app/app/messages/studio_tips_notice.rb` (dismissible campaign), `terms_update_notice.rb` (blocking campaign with `period_key`) and `class_canceled_notice.rb` (blocking delivery).

## Registering notices

```ruby
CommandTower.configure do |config|
  config.home_notices.enabled = true
  config.home_notices.notices = %w[MakeYourPicks]
end
```

Class names are Strings so reloading works. Config options are listed in [`bootstrap/08-initializer.md`](bootstrap/08-initializer.md).

## Boot checks

When `enabled`, the engine's `to_prepare` runs `CommandTower::HomeNotices::Catalog.load!`. The first problem raises `Catalog::InvalidNoticeError` in every environment. The checks:

- Each name constantizes and subclasses `Campaign` or `Delivery`.
- `key` is present, matches the format, does not use `ct.`, and is unique.
- `severity` and `priority` are present.
- A blocking notice has a `blocking_reason` of at least 20 characters.
- A dismissible campaign declares `impressions`.
- `composer` is used only on a Delivery; `impressions` and `period_key` only on a Campaign.
- `show?` is overridden. A linked delivery (`composer :message`) counts as overriding it.
- `compose` is overridden, unless the delivery is linked.
- `window` has `starts_at` before `ends_at`.

`global_cooldown` below 1 hour also fails at boot.

## Selection

`CommandTower::Services::HomeNotices::Select` chooses at most one blocking and one dismissible notice for a user and request. Every time rule uses `context.now`. Success data is `{ candidates:, controls_available:, blocking:, dismissible: }`.

1. **Load.** `LoadCandidates` gathers the user's open deliveries (unacknowledged, not ended, oldest first, at most `max_open_deliveries`, registered Delivery keys only) and every registered campaign with its current-period row, or no row yet. A campaign whose `period_key` block raises is skipped and `period_key_failed` is published.
2. **Drop.** A candidate is dropped when it is killed, outside its window, acknowledged, dismissed into the future (`dismissed_until > now`), or (campaigns only) at its period impression `max` or inside its item `cooldown` (`last_shown_at + cooldown > now`). The kill switch reads `command_tower_home_notice_controls`; an absent row means enabled. Windows apply to the class `window` and to the row's own `starts_at` / `ends_at`; `starts_at` is inclusive and `ends_at` exclusive. Deliveries have no item pacing.
3. **Order.** Highest `priority` first, ties to the oldest row (`created_at`). A campaign with no row counts as newest.
4. **Pick.** `PickNotices` makes one pass per severity. Nothing is picked when `context.ui_catalog` is below 2. Otherwise the first candidate that passes its gate, then `show?`, then `compose` wins; a notice whose compose fails is skipped.
   - **Blocking daily cap.** A notice already started (`first_shown_at` set) is always re-served until acknowledged. A new one needs fewer than `blocking_daily_cap` of the user's blocking rows first shown in the current UTC day.
   - **Dismissible global cooldown.** Clear when the latest `last_shown_at` over the user's dismissible rows plus `global_cooldown` is at or before `now`. A delivery also passes when its `ends_at` is at or before the moment the cooldown clears. Blocking impressions do not start the cooldown.
   - **`show?` budget.** `show?` has 50 ms. An overrun publishes `show_if_slow` and the answer is still used. An exception means "not shown" and publishes `show_if_failed`.

### Failure behavior

If the controls cannot be read, selection fails closed: no candidates, no picks, `controls_available: false`, and `controls_unavailable` is published (user id and error class).

### Events

All are in category `home_notices`. Payloads carry ids, keys, counts and error classes, never document content.

| Event | When |
|---|---|
| `selected` | Selection finished: user id, candidate count, picked blocking and dismissible keys |
| `controls_unavailable` | The controls read failed |
| `period_key_failed` | A campaign `period_key` block raised |
| `show_if_slow` | `show?` took longer than 50 ms |
| `show_if_failed` | `show?` raised |
| `delivery_over_cap` | `Deliver` ignored a delivery over `max_open_deliveries` (key only) |
| `linked_mark_failed` | Acknowledge could not mark the linked inbox item viewed (ids, error class) |

### Cap overshoot

The blocking daily cap is not transactional. Selection counts rows before any impression is recorded, so concurrent requests can each start a different blocking notice before either impression lands. The cap can be exceeded by one per concurrent request. This is accepted (design D5): re-serving a started notice is always allowed, and the next request sees the new rows and holds the cap.

## Deliver

`CommandTower::Services::HomeNotices::Deliver` pushes one `Delivery` notice to one user. A host workflow calls it directly, usually right after `Produce`.

| Input | Meaning |
|---|---|
| `user`, `notice` | The recipient and the `Delivery` subclass (anything else fails validation) |
| `identity` | The caller's stable key for this occurrence |
| `communication_id` | Required for a linked delivery (`composer :message`) |
| `starts_at`, `ends_at`, `metadata` | Optional window and a Hash of ids and small values |

- **Idempotent** on `(user, identity)`: a repeat returns the existing row and writes nothing.
- **Cap.** Over `max_open_deliveries` open rows the delivery is ignored and `delivery_over_cap` is published (key only).
- **Linked delivery.** The row is refused with `linked_message_unavailable` when the inbox item is missing, deleted, foreign or undefined, checked through `Messaging::Contract::Inbox.document_for_communication` ([Messaging guide](messaging_integration_guide.md)). No row is written.
- Success data is `{ delivered:, public_id: }`. `delivered` is true only when this call wrote the row; `public_id` is nil when ignored over the cap.

### Linked deliveries

A delivery with `composer :message` needs no `show?` or `compose`:

- **Document.** `Compose` takes the inbox item's own document from `document_for_communication` instead of calling `compose`. It is redacted and validated like any other notice. A missing, deleted, archived, foreign or undefined item yields no document, so the notice is not shown.
- **Shown while unviewed.** The `Delivery#show?` default is true while `viewed_for_communication?` is false, and false when it is true (viewed) or nil (unavailable). Hosts may override `show?` and call `super`. An unlinked delivery must override `show?`.
- **Acknowledge marks viewed.** After the acknowledge commits (also on an idempotent repeat), the workflow calls `mark_viewed_for_communication`. This is best effort: a failure publishes `linked_mark_failed` (ids and error class) and never fails the acknowledgement.

Sample: `rails_app/app/messages/class_canceled_notice.rb`.

## HTTP

`GET /me/home-notices` (engine-relative; hosts mounting at `/api` use `GET /api/me/home-notices`). Full contract: [API reference](api_reference.md#get-mehome-notices).

- Routed only when `config.home_notices.enabled` is true; otherwise **404**.
- RBAC entity `me_home_notices` (`Me::HomeNoticesController`). Not part of `member`; hosts grant it explicitly. RBAC fails closed, so a user without the grant gets **403**.
- Response `data`: `{ blocking, dismissible, readOnly }`. Each notice is `null` or a serialized document. `readOnly` is true while impersonating, or when impersonation state is unknown. An impersonated response redacts the documents.
- A client below UI catalog 2 (`X-UI-Catalog`) gets both notices `null`.
- Always sends `Cache-Control: no-store`.
- Rate limit: `config.home_notices.rate_limit_per_minute` (30) per user. The 31st call in a minute returns **429** `home_notices_rate_limited`. A limiter failure fails open (200) and publishes `rate_limiter_unavailable`.

## Kill switch runbook

Use the kill switch to stop one notice key everywhere without a deploy. A key with no control row is enabled; the first change creates the row.

```
PATCH /admin/home-notices/<key>      (add the /api prefix on a host that mounts there)
{ "enabled": false }
```

- `<key>` is the notice key (`[a-z0-9_]` segments joined by dots, at most 128 characters). It must be a registered notice in the loaded catalog; an unknown key is **404** and nothing is written.
- Send a strict boolean `enabled`. `false` kills the key; `true` restores it.
- Effect: the next `GET /me/home-notices` drops the key, and impression, acknowledge and dismiss for it return 404. No restart is needed. Rows already persisted are kept, so re-enabling resumes pacing where it left off.
- Needs the `admin_home_notices_kill` grant. The owner role has it through `entities: true`; every other role needs an explicit grant (see [Bootstrap RBAC](bootstrap/09-rbac.md)). It is not a principal capability, so no client gates on it. The call is refused while impersonating.
- Repeating the current state is a **200** no-op and is not audited. A change emits `home_notice_control_changed` ([Audit](audit.md)).
- Contract: [API reference](api_reference.md#patch-adminhome-noticeskey).
- If the controls cannot be read or written, the platform fails closed: selection returns no notices and mutations return **503** `home_notices_unavailable`.

## Local verification

Verify against the dummy app with `curl`. Tokens go in **header files** under `rails_app/tmp/lane-auth/` (gitignored through `/rails_app/tmp/`) and are passed with `curl -H @file`. A token never appears on a command line or in a log. Do not `cat` or print these files.

1. Write the mint script to `rails_app/tmp/lane-auth/mint.rb`. It creates (or reuses) three users and writes one header file each:

```ruby
dir = Rails.root.join("tmp/lane-auth")
FileUtils.mkdir_p(dir)

def lane_user(email, username, roles)
  User.find_by(email:) || User.create!(
    email:, username:, first_name: "Lane", last_name: username.capitalize,
    password: SecureRandom.hex(16), email_validated: true, roles:
  )
end

def write_header(dir, name, token)
  path = dir.join(name)
  File.write(path, "Authorization: Bearer #{token}\n")
  File.chmod(0o600, path)
end

owner  = lane_user("lane-owner@example.com", "laneowner", ["owner"])
nogrant = lane_user("lane-nogrant@example.com", "lanenogrant", [])
target = lane_user("lane-target@example.com", "lanetarget", ["home_notices_reader"])

write_header(dir, "owner.header", CommandTower::Jwt::LoginCreate.call(user: owner).token)
write_header(dir, "nogrant.header", CommandTower::Jwt::LoginCreate.call(user: nogrant).token)

session = CommandTower::Services::Impersonation::Create.call(actor: owner, target:).data[:session]
write_header(dir, "impersonation.header",
  CommandTower::Jwt::LoginCreate.call(user: owner, impersonation_session_id: session.id).token)
```

2. Run it: `make runner CMD='load Rails.root.join("tmp/lane-auth/mint.rb").to_s'`. It prints nothing. Re-run it to refresh tokens (they expire with `config.jwt.ttl`; the impersonation session also has idle and absolute timeouts).
3. Call the endpoint with `curl -i -H @rails_app/tmp/lane-auth/owner.header -H 'X-UI-Catalog: 2' http://localhost:3000/me/home-notices` (add the `/api` prefix on a host that mounts there). Use `X-UI-Catalog: 1` for the null-notices case.

Expected results:

| Header file | Expected |
|---|---|
| `owner.header` | 200, `Cache-Control: no-store`, `readOnly: false` |
| `nogrant.header` | 403 |
| `impersonation.header` | 200, `readOnly: true`, documents redacted (the target holds `home_notices_reader`) |
| `owner.header` against `GET /auth/principal-capabilities` | `principalCapabilities` includes `me_home_notices` |
| `nogrant.header` against `GET /auth/principal-capabilities` | does not include `me_home_notices` |

The dummy app's `home_notices_reader` group is in `rails_app/config/rbac_groups.yml`.

## Persistence

Two tables, both additive: `command_tower_home_notices` (one row per user and notice, with `period_key` empty for deliveries and `campaign_key` NULL for deliveries) and `command_tower_home_notice_controls`. See [Models](models.md).

## Related

- [Initializer config](bootstrap/08-initializer.md)
- [UI](ui.md)
- [Models](models.md)
