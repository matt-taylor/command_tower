# Home Notices

Home Notices let a host show a notice to a signed-in user on the home surface. The host declares each notice as a class. The platform owns pacing, windows, selection and audit. This page covers **authoring** and the boot checks. Later behavior (selection, endpoints, delivery, kill switch) is added here as it ships.

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

## Persistence

Two tables, both additive: `command_tower_home_notices` (one row per user and notice, with `period_key` empty for deliveries and `campaign_key` NULL for deliveries) and `command_tower_home_notice_controls`. See [Models](models.md).

## Related

- [Initializer config](bootstrap/08-initializer.md)
- [UI](ui.md)
- [Models](models.md)
