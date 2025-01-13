# ApiEngineBase Service

`ApiEngineBase::ServiceBase` an abstraction around the Ruby Gem Interactor. It dds custom functionality to the base Service and is intended to be an inherited Class to create Application logic code. All Services in `ApiEngineBase` utilize this base Service class for convenience and DRYness.

## What does ServiceBase offer

### Logging
`ServiceBase` offers a convenient way to tag logs. It keeps track of:
- The start of the the Logic call
- The time it took to complete the logic
- The status of the logic

Additionally, it provides some convenience methods for logging
- `log_debug`
- `log_info`
- `log_warn`
- `log_error`

### Argument Validation
Argument Validation is the powerhouse behind ServiceBase

Customized argument validation can be created by adding the method `validate!`
```ruby
class MyServiceClass < ApiEngineBase::ServiceBase

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

For More information, Check out the [ArgumentValidation ReadMe](argument_validation/README.md)


## Basic Examples:
Check out the examples used in this directory!



