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

### Cap overshoot

The blocking daily cap is not transactional. Selection counts rows before any impression is recorded, so concurrent requests can each start a different blocking notice before either impression lands. The cap can be exceeded by one per concurrent request. This is accepted (design D5): re-serving a started notice is always allowed, and the next request sees the new rows and holds the cap.

## Persistence

Two tables, both additive: `command_tower_home_notices` (one row per user and notice, with `period_key` empty for deliveries and `campaign_key` NULL for deliveries) and `command_tower_home_notice_controls`. See [Models](models.md).

## Related

- [Initializer config](bootstrap/08-initializer.md)
- [UI](ui.md)
- [Models](models.md)
