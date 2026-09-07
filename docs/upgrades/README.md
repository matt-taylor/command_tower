# Upgrades

Host-facing upgrade / change summaries for CommandTower releases.

| Version | Summary |
|---------|---------|
| [0.16.0](0.16.0.md) | Me experience-states (`GET`/`POST complete`); `host_key`; `user_experience_states` migration; `me_experience_states` RBAC |
| [0.15.0](0.15.0.md) | Me `POST /me/push/test` → Produce (`push_delivery_test`); configurable Expo self-test rate limit composers; `me_push#test` |
| [0.14.0](0.14.0.md) | Expo push Messaging channel (`config.messaging.expo`) + `/api/me/push*` registration HTTP; `me_push` RBAC |
| [0.13.1](0.13.1.md) | Canonical `Intervention::Severity` constants (`blocking`, `warning`, `informational`) |
| [0.13.0](0.13.0.md) | Account self-service deletion (`DELETE /api/me/account`); tombstone + PII scrub; `me_account` RBAC; `users.deleted_at` migration |
| [0.12.0](0.12.0.md) | Intervention envelope serializers/deserializers; product-tool admin_scope without Users/Audit narrowing |
| [0.11.1](0.11.1.md) | Audit Event `attribute :json` (MariaDB); audit migration without `utf8mb4_0900_ai_ci` |
| [0.11.0](0.11.0.md) | Execution context, audit ledger, Admin Workspace, principal capabilities, impersonation, Admin Users |
| [0.10.0](0.10.0.md) | Modern Auth/Me/Messaging platform; SchemaHelper removal; host RBAC required |

New hosts should start with [Host integration](../host_integration_guide.md).
