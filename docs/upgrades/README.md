# Upgrades

Host-facing upgrade / change summaries for CommandTower releases.

| Version | Summary |
| [0.13.0](0.13.0.md) | Account self-service deletion (`DELETE /api/me/account`); tombstone + PII scrub; `me_account` RBAC; `users.deleted_at` migration |
|---------|---------|
| [0.12.0](0.12.0.md) | Intervention envelope serializers/deserializers; product-tool admin_scope without Users/Audit narrowing |
| [0.11.1](0.11.1.md) | Audit Event `attribute :json` (MariaDB); audit migration without `utf8mb4_0900_ai_ci` |
| [0.11.0](0.11.0.md) | Execution context, audit ledger, Admin Workspace, principal capabilities, impersonation, Admin Users |
| [0.10.0](0.10.0.md) | Modern Auth/Me/Messaging platform; SchemaHelper removal; host RBAC required |

New hosts should start with [Host integration](../host_integration_guide.md).
