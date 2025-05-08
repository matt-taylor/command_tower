# CommandTower
This is an API only base engine to build on top of. This Engine takes care of all Authentication, Token Refresh, and RBAC Roles so that you do not have to! For all applications, you can get right to work on implementing the code directly related to your project rather than dealing with the administrative overhead.

While this gem is heavily opinionated, everything can be configured to your liking.

## Installation
Add this line to your application's Gemfile:

```ruby
gem "command_tower"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install command_tower
```

## Initializing CommandTower
Please follow all steps in [Initializing CommandTower](docs/initializing.md)


## Available Routes

For more info, check out [Controllers ReadMe](docs/controllers.md)

Additionally, You can check out [RSpec Integration Testing](/spec/integration_test)

## Available Models

CommandTower provides several Models at the in the root namespace. Core Models like `User` and `UserSecret` are readily available. Don't forget! You can add additional methods to these classes by opening them back up.

For more info, check out [Models ReadMe](doc/models.md)

## Authentication (JWT BearerToken)
Authentication ensures that we know which user is requesting the action. When the Engine is unable to authenticate, a `401` status code is returned.

For more info, check out [Authentication ReadMe](docs/authentication.md)

## Authorization (RBAC)
Authorization is only done after authentication. This is the act of ensuring that the user can perform the action it is requesting. Put differently, I know who you are, but I need to validate you have permissions to complete the action. When the engine is unable to authorize the user, a `403` status code is returned.

For more info, check out [Authentication ReadMe](docs/authorization.md)

## Sensitive Changes

For more info, check out [Sensitive Routes](docs/sensitive_routes.md)

## ServiceBase
ServiceBase is built on top of Interactor. The ServiceBase is the heart of all logic for CommandTower. It includes Logging and enhanced ArgumentValidation that can directly return back to the API request.

For more info, check out [ServiceBase ReadMe](app/services/command_tower/README.md)

## Pagination
Pagination is available on routes when explicitly set. There are a subset of routes available as part of this engine. Pagination is available to be used in downstream services as well. For more info, check out [Pagination ReadMe](docs/pagination.md)

## License
The engine is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
