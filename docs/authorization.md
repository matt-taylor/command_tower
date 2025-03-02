# Authorization via RBAC

Some users will have different permissions than others. RBAC based permissions can be route specific or controller specific.

## Integrate Authorization
Authorization requires routes that have a `current_user` defined. Current User is defined by default via [Authentication](authentication.md) but you can also define it yourself.

After defining the role, set the before_action
```ruby
# Order is important here
# authorize_user! depends on current_user being defined via authentication
before_action :authenticate_user!
before_action :authorize_user!
```

## Default roles
Default roles are statically defined in [lib/command_tower/authorization/default.yml](../lib/command_tower/authorization/default.yml).

Roles include:
- `owner`: Users defined as owner will have access to every route regardless of required roles
- `admin`: Users defined as admin will have full access to all actions on the `AdminController`. This includes the ability to change settings on other users and impersonate other users
- `admin-without-impersonation`: Users defined with this role can hit all AdminController actions except `impersonate`
- `admin-read-only`: Users defined with this role can only hit the index page for viewing existing users and their settings.


## Creating new Roles

### From Config File
Additional roles can be defined via a separate yml file that you can define from the [Initializer Config option](initializing.md) `CommandTower.config.authorization.rbac_group_path` (By default we will look in `config/rbac_groups.yml`)

### From Code File
Defining code files is only recommended if you require complex user authorization. For more details check out the Spec tests
[/spec/lib/command_tower/authorization/role_spec.rb](/spec/lib/command_tower/authorization/role_spec.rb) (`with custom authorized entity`)

