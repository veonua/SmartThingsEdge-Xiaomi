---
name: smartthings-capabilities
description: Verify and use existing SmartThings capabilities in Edge driver Lua and profile YAML. Use before adding any `capabilities.*` reference, profile capability ID, attribute emission, command handler, or custom capability proposal.
---

# SmartThings Capabilities

Verify the live registry definition before using a capability. Do not infer capability IDs, attribute names, units, commands, or versions from another platform's feature name.

## Workflow

1. Identify the proposed capability ID and the device value/command it must represent.
2. Query the standard registry:

   ```sh
   smartthings capabilities <capability-id> --standard --json
   ```

3. Read the result and record the capability version, attributes, value schema, allowed units, and commands.
4. Add the matching Lua reference (`capabilities.<id>`), profile entry, emitted attribute event, and command handler only when the registry definition supports each use.
5. Add a test that constructs the verified attribute or command. Reject unsupported units and values before emitting them.
6. If the capability is absent or unsuitable, stop and propose either a supported standard mapping or a custom capability. Do not create a custom capability without explicit authorization.

## Required Evidence

Include this record with the implementation:

```text
Capability: <id>, version <n>, standard/custom
Registry command: smartthings capabilities <id> --standard --json
Attribute/command: <name>
Schema: <value type and allowed units or enum values>
Driver mapping: <Lua emitter/handler and profile component>
```

## References

- Read [registry-lookup.md](references/registry-lookup.md) for CLI and API lookup rules.
- Read [verified-standard-capabilities.md](references/verified-standard-capabilities.md) for locally verified examples. Re-query the registry if the capability contract matters to a new change.
