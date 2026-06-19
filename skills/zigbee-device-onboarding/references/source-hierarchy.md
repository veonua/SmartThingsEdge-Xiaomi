# Source Hierarchy

Use the highest applicable source. Preserve the source URL or repository path in the evidence record.

1. Device-specific Zigbee2MQTT page: `https://www.zigbee2mqtt.io/devices/<device_model>.html`. Use it for product identity, user-visible feature inventory, and named endpoint behavior.
2. Upstream converter implementation: [zigbee-herdsman-converters](https://github.com/Koenkk/zigbee-herdsman-converters), especially [`src/devices/`](https://github.com/Koenkk/zigbee-herdsman-converters/tree/master/src/devices) and the invoked helper under [`src/lib/`](https://github.com/Koenkk/zigbee-herdsman-converters/tree/master/src/lib). Use it for endpoints, clusters, report decoding, attributes, types, and values.
3. Zigbee2MQTT application repository: [Koenkk/zigbee2mqtt](https://github.com/Koenkk/zigbee2mqtt). Use it for documentation generation, integration context, and issues; do not use it as a substitute for the converter definition.
4. SmartThings upstream driver patterns: [SmartThingsCommunity/SmartThingsEdgeDrivers](https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers). Use it for platform-compatible capability, preference, and lifecycle approaches.
5. Local implementation: inspect the target driver’s `fingerprints.yml`, `profiles/`, `src/`, and `src/test/`. Use it for repository conventions and regression boundaries.
6. Model documentation or captured device descriptors. Use these to resolve gaps, but mark unverified claims as assumptions.

When sources conflict, prefer target-model converter code over generic documentation. Prefer observed descriptors over model-name inference. Do not generalize a private attribute across Aqara/Xiaomi product lines without target-model evidence.

## Local Discovery

Start with:

```sh
rg -n "<model>|<manufacturer>|<cluster-id>" . --glob '!**/.git/**'
rg --files <driver-directory>
```

Read `skills/aqara-custom-clusters/SKILL.md` for the known Lumi/Aqara manufacturer-cluster catalogue. Treat its collision warnings as mandatory: confirm attribute semantics per model.
