# CommandTower ServiceBase

`CommandTower::ServiceBase` is an abstraction around the Ruby gem Interactor. It adds logging and argument validation on top of Interactor and is the inherited base for **service** classes that implement one business capability.

Services sit **under** workflows in the platform layer map:

```text
Controller / Job → Workflow → Shared Sequences / Services → Models & Clients
```

Workflows own orchestration of a business action. Services own how a single capability is performed. Do not treat ServiceBase as the application orchestrator — that is the workflow layer.

Long-form architecture rationale: `artifacts/rails_architecture_handbook.md` (workspace). Condensed enforcement: `.cursor/rules/rails-architecture.mdc` and `.cursor/rules/services.mdc`.

All services in CommandTower that use this pattern inherit `CommandTower::ServiceBase` for consistency.

## What does ServiceBase offer

### Logging

Lifecycle logging is an `ActiveSupport::Notifications` consumer. Services do not write Start/Finished lines to `Rails.logger`.

Operational notes from services still use `log_info` / `log_warn` / `log_error`, which publish `command_tower.log.*` events. See [Eventing](../../../docs/eventing.md).

### Argument Validation
Argument Validation is the powerhouse behind ServiceBase

Customized argument validation can be created by adding the method `validate!`
```ruby
class MyServiceClass < CommandTower::ServiceBase

  def call
  end

  def validate!
    # run custom validations before executing call
  end
end
```

Other more complex Argument validation includes:
- Validating Presence of Argument
- Validating Type of argument
- Validating a composition of argument values (At least, At Most, Exactly)
- Delegate context variable to the class for simplicity
- Validating Argument length or size is `<` `≤` `==` `>` `≥`

For more information, see the [ArgumentValidation ReadMe](argument_validation/README.md)


## Examples in the gem

There is no separate examples directory under this path. Real service classes live under capability namespaces, for example:

- `CommandTower::Services::Messaging::Communications::Produce`
- `CommandTower::Services::Messaging::Communications::ProduceMany`
- `CommandTower::Services::Me::ChangePassword`

See [Messaging](../../../docs/messaging_integration_guide.md) and [Extending](../../../docs/extending.md).
