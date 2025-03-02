# CommandTower Models

## User
The User model is the core model behind any user facing application.

Through the User model, this engine is able to provide base competencies such as [Authentication via JWT](authentication.md) and [Authorization via RBAC](authorization.md).


Sometimes, you may want to add additional methods to the User Class. While we advocate for adding additional logic into Service objects, this may be unavoidable. To ReOpen the User Class simple do the following
```ruby
require CommandTower::Engine.root.join("app","models", "user.rb")

class User
  def self.my_class_method; end
  def my_instance_method; end
end
```

## UserSecret
This model helps back some of the validation components. For example, it backs the Email validation via PlaintText authentication. Additionally, it backs the core competency of [Sensitive Changes](sensitive_routes.md).

Sometimes, you may want to add additional methods to the UserSecret Class. While we advocate for adding additional logic into Service objects, this may be unavoidable. To ReOpen the UserSecret Class simple do the following
```ruby
require CommandTower::Engine.root.join("app","models", "user_secret.rb")

class UserSecret
  def self.my_class_method; end
  def my_instance_method; end
end
```
