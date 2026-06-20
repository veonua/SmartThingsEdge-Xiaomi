# Registry Lookup

## Primary Source: SmartThings CLI

Use the installed CLI against the live registry:

```sh
smartthings capabilities <id> --standard --json
smartthings capabilities --standard --json
smartthings capabilities:presentation <id> --capability-version <version> --json
```

The first command verifies that the capability is standard and returns its canonical ID, version, attribute schemas, valid units, and commands. Use the presentation command only when dashboard/detail display matters.

The CLI may need normal access to its user log directory. Treat that as a tool-runtime permission issue, not evidence that a capability is absent.

## Official Fallback

Use the SmartThings public capability API documentation when the CLI is unavailable or unauthenticated:

- [List capabilities](https://developer.smartthings.com/docs/api/public/#operation/listCapabilities)
- [Get capability](https://developer.smartthings.com/docs/api/public/#operation/getCapability)

Do not use third-party device integrations as proof of a SmartThings capability contract.

## Mapping Checklist

- Profile: use the returned `id` and `version`.
- Lua: access `st.capabilities.<id>` and the returned attribute/command names exactly.
- Event: include only required fields and an allowed unit.
- Commands: implement only commands present in the registry response.
- Tests: build the same attribute event or command used by the driver.
