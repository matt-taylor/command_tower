# 07 — Execution-boundary bases

## Purpose

Host controllers and jobs inherit CommandTower bases so authentication, request context, envelope rendering, and job execution stay on the platform path.

## Prerequisites

- [`06-mount-and-health.md`](06-mount-and-health.md)

## Files the host edits

| File | Inherit |
|------|---------|
| `app/controllers/application_controller.rb` | `CommandTower::ApplicationController` |
| `app/jobs/application_job.rb` | `CommandTower::ApplicationJob` |

## Procedure

Replace the default `ActionController::API` / `ActiveJob::Base` superclasses:

```ruby
class ApplicationController < CommandTower::ApplicationController
end
```

```ruby
class ApplicationJob < CommandTower::ApplicationJob
end
```

Host controllers then subclass `ApplicationController` as usual. Do not subclass `ActionController::API` for product JSON that should share CommandTower auth and envelope behavior.

Background work invokes **workflows** (via CommandTower job helpers), not services as a full business action. See [`../architecture.md`](../architecture.md).

## Stop

`ApplicationController` and `ApplicationJob` inherit CommandTower bases. Next: [`08-initializer.md`](08-initializer.md).
