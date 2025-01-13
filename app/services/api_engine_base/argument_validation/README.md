# Argument Validation

Argument validation provides a robust framework to ensure correctness of arguments before executing any application logic code. This was created because when in use with an API, this can help provide reusable messaging directly back to the API when the parameters are incorrect.

## Argument Validation
Argument Validation provides service object code assurances on what to expect for inputted arguments.

Available arguments:
- `default`: Default value to set the argument when not provided by user
- `is_a`: The allowed types of the passed in argument. Will also check if the type is in the ancestral tree
- `is_one`: Checks a direct comparison if the input is one of these values. Note: while not disallowed, `is_a` and `is_one` should not be used together
- `length`: (used with operators exclusively) When set to true, the operators will use the length of value rather than the exact value
- `lt`: When provided, argument must be less than this value
- `lte`: When provided, argument must be less than or equal to this value
- `eq`: When provided, argument must be equal to this value
- `gte`: When provided, argument must be greater than or equal to this value
- `gt`: When provided, argument must be greater than this value
- `delegation`: (Default set to true) - Sets the delegation on the object. This allows you to reference the argument name rather than the context.{argument_name}
- `sensitive`: This marks the argument as sensitive. It will scrub the value of the argument when returning the context to the caller
- `required`: When set, this marks the argument as required. If not provided, validations are not run. When provided, validations must pass

## Argument Composition
Argument Compositions are made up of 1 or more Argument Validations. The intention of compositions are to ensure `at_most`, `at_least`, or `exactly` X argument validations are provided by the user.

### Composition: At Most
At most composition expects at most X arguments to get passed into the instance.

```ruby
class ServiceExample < ApiEngineBase::ServiceBase
  at_most 2, :name_of_composition, required: true do
    validate :email, is_a: String
    validate :phone, is_a: String
    validate :username, is_a: String
  end

  def call; end
end
```

```ruby
rails-app(dev)> ServiceExample.(email: "email", phone: "phone", username: "username")
=> # Composite Key failure for name_of_composition [name_of_composition]. Expected at most 2 keys assigned. Provided values for the following keys: [:email, :phone, :username]. Available keys [:email, :phone, :username] (ApiEngineBase::ServiceBase::CompositionValidationError)
```

### Composition: At Least
At least composition expects at least X arguments to get passed into the instance.

```ruby
class ServiceExample < ApiEngineBase::ServiceBase
  at_least 2, :name_of_composition, required: true do
    validate :email, is_a: String
    validate :phone, is_a: String
    validate :username, is_a: String
  end

  def call; end
end
```

```ruby
rails-app(dev)> ServiceExample.(email: "email")
=> # Composite Key failure for name_of_composition [name_of_composition]. Expected at least 2 keys assigned. Available keys. Provided values for the following keys: [:email]. Available keys [:email, :phone, :username] (ApiEngineBase::ServiceBase::CompositionValidationError)
```

**Noteworthy**: `at_least` can take in any integer for its `count`. However, we found that most people just need one. For that reason, the convenience method of `at_least_one` was created. It can be used without the `count` argument in `at_least`

### Composition: Compose Exact
Compose Exact composition expects exactly X arguments to get passed into the instance. For this composition to be valid, there must be X or more validations.

```ruby
class ServiceExample < ApiEngineBase::ServiceBase
  compose_exact 2, :name_of_composition, required: true do
    validate :email, is_a: String
    validate :phone, is_a: String
    validate :username, is_a: String
  end

  def call; end
end
```
```ruby
rails-app(dev)> ServiceExample.(email: "email")
=> # Composite Key failure for name_of_composition [name_of_composition]. Expected [2] of the keys to have a value assigned. But 1 keys were assigned. Provided values for the following keys: [:email]. Available keys [:email, :phone, :username] (ApiEngineBase::ServiceBase::CompositionValidationError)
```

**Noteworthy**: `compose_exact` can take any `count` value to dynamically provision the exact component. However, we found that we almost only just needed count == 1. We have provided a convenience method of `one_of` without the `count` variable to simplify. There are quite a few examples of this already created

### Custom Compositions
All compositions are built on top of the same underlying function. This allows you to build additional compositions to add custom logic for validations and what not.
Check out the [ClassMethods Source Code](class_methods.rb) on what method arguments are required.


## Argument validation Failures
When an argument validation fails (whether that is a single `validate` or a composition), there are 3 options on what to do:

### Raise an error (Default)
As you can see in the examples above, the default for argument validation failures is to raise the following error
```ruby
ApiEngineBase::ServiceBase::CompositionValidationError
```

The expected behavior is:
- Downstream code catches the failure and handles it correctly
- Service Logic code is not executed

This failure mode can get explicitly set via:
```ruby
class ServiceExample < ApiEngineBase::ServiceBase
  on_argument_validation :raise

  one_of :name_of_composition, required: true do
    validate :email, is_a: String
    validate :phone, is_a: String
    validate :username, is_a: String
  end

  def call; end
end
```

### Fail the context Early (Recommended)
Failing the context early is we recommend to do for your service objects. This mode provides an exceptionally amount of context into **HOW** the validation failed and what needs to get corrected.


The expected behavior is:
- Downstream code checks for `result.failure?` and continues accordingly
- Service Logic code is not executed
- Nothing is raised

```ruby
class ServiceExample < ApiEngineBase::ServiceBase
  on_argument_validation :fail_early

  one_of :name_of_composition, required: true do
    validate :email, is_a: String
    validate :phone, is_a: String
    validate :username, is_a: String
  end

  def call; end
end
```
```ruby
result = ServiceExample.(email: :not_a_string)
if result.success?
else
  if result.invalid_arguments
    # context.fail! was called by argument validation
    puts result.invalid_arguments
    puts result.invalid_argument_hash
    puts result.invalid_argument_keys
  else
    # context.fail! was called by user
  end
end
=> true
=> {:email=>{:msg=>"Parameter [email] must be of type String. Given Symbol [not_a_string]", :required=>nil, :is_a=>String}}
=> [:email]

result = ServiceExample.()
result.invalid_arguments
=> true
result.invalid_argument_hash
=> {:name_of_composition=>{:msg=>"Composite Key failure for name_of_composition [name_of_composition]. Expected [1] of the keys to have a value assigned. But no key was assigned. Provided values for the following keys: []. Available keys [:email, :phone, :username]", :required=>nil, :is_a=>nil}}
result.invalid_argument_keys
=> [:name_of_composition]

result = ServiceExample.(email: 7, username: 8)
result.invalid_arguments
=> true
result.invalid_argument_hash
=> {:email=>{:msg=>"Parameter [email] must be of type String. Given Integer [7]", :required=>nil, :is_a=>String}, :username=>{:msg=>"Parameter [username] must be of type String. Given Integer [8]", :required=>nil, :is_a=>String}, :name_of_composition=>{:msg=>"Composite Key failure for name_of_composition [name_of_composition]. Expected [1] of the keys to have a value assigned. But 2 keys were assigned. Provided values for the following keys: [:email, :username]. Available keys [:email, :phone, :username]", :required=>nil, :is_a=>nil}}
=> [:email, :username, :name_of_composition]
```

### Log and Continue (Not Recommended)
This mode will allow you to log the validation failure and continue. We do not recommend this


```ruby
class ServiceExample < ApiEngineBase::ServiceBase
  on_argument_validation :log

  one_of :name_of_composition, required: true do
    validate :email, is_a: String
    validate :phone, is_a: String
    validate :username, is_a: String
  end

  def call; end
end
```
