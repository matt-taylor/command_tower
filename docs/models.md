# CommandTower Models

Core models live in the root / CommandTower namespaces and support authentication, authorization, and messaging ledger associations.

Back to [README](../README.md).

## User

`User` is the primary identity model for host applications.

It underpins [Authentication](authentication.md) and [Authorization](authorization.md), and participates in messaging via associations such as `messaging_communications`.

Sensitive session invalidation uses the user’s verifier token — see [Sensitive changes](sensitive_routes.md).

### Reopening `User` in the host

Prefer services/workflows for new behavior. When you must reopen the class:

```ruby
require CommandTower::Engine.root.join("app", "models", "user.rb")

class User
  def self.my_class_method; end
  def my_instance_method; end
end
```

## UserSecret

`UserSecret` backs validation and recovery-related secrets (for example plain-text email validation flows). It complements [Sensitive changes](sensitive_routes.md).

### Reopening `UserSecret` in the host

```ruby
require CommandTower::Engine.root.join("app", "models", "user_secret.rb")

class UserSecret
  def self.my_class_method; end
  def my_instance_method; end
end
```

## Messaging models

Engine-owned messaging persistence (communications, endpoints, preferences, and related records) ships with CommandTower. Prefer platform services/workflows for mutations; do not dual-author schema in the host ([Initializing](initializing.md)).

## Audit ledger

`CommandTower::Audit::Event` is the append-only platform ledger (`command_tower_audit_events`). Only `CommandTower::Audit::Persistence::Subscriber` writes rows. There are no foreign keys to users. Envelope `changes` persist as `change_set`. See [Audit](audit.md).

## Related

- [Architecture](architecture.md)
- [Sensitive changes](sensitive_routes.md)
- [Testing](testing.md) — shared factories for CT-owned models
