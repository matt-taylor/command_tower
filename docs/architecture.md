# CommandTower Architecture (host-facing)

CommandTower is a mountable Rails engine. Host applications consume platform capabilities through engine HTTP, configuration, and shared factories. Product behavior stays in the host.

## Layer map

```text
Controller / Job → Workflow → Shared Sequences / Services → Models & Clients
```

| Layer | Owns | Does not own |
|-------|------|--------------|
| Controller | Transport, auth preconditions, deserialization, **one** workflow, envelope render | Business rules, persistence, external I/O |
| Workflow | Orchestration of one business action | Capability implementation details |
| Shared sequence | Reusable orchestration fragments | External entry points |
| Service | One business capability (`ServiceBase` / ApplicationService) | Workflows, transport |
| Model | Persistence and data validation | Orchestration, external I/O |
| Client | External system I/O | Business orchestration |

**Hard rule:** meaningful business behavior enters through a workflow—never directly from a controller into a service for a full business action.

## Where to read more

- Long-form rationale (workspace): `artifacts/rails_architecture_handbook.md`
- Condensed enforcement (workspace): `.cursor/rules/rails-architecture.mdc`
- Service capability base: [ServiceBase README](../app/services/command_tower/README.md)
- Install and host ownership: [Initializing](initializing.md)
- Host extension boundaries: [Extending](extending.md)

Back to [README](../README.md).
