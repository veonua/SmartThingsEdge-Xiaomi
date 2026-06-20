---
name: zigbee-device-onboarding
description: Add or extend Zigbee device support in this SmartThings Edge repository. Use when asked to support a new Zigbee manufacturer/model, add a fingerprint, profile, endpoint mapping, child device, manufacturer-specific feature, telemetry handler, or device regression test.
---

# Zigbee Device Onboarding

Use evidence before implementation. Treat model identity, endpoints, cluster support, and manufacturer attributes as model-specific until verified.

## Workflow

1. Gather the exact manufacturer string, Zigbee model, region/variant, and requested behavior. Ask only for facts that cannot be discovered.
2. Open `https://www.zigbee2mqtt.io/devices/<device_model>.html` and record its public feature set.
3. Locate the matching definition in `Koenkk/zigbee-herdsman-converters`; read the model definition and every shared helper it invokes.
4. Build an endpoint matrix: endpoint, clusters, control capability, reports/actions, and any manufacturer-specific reads or writes.
5. Read [source-hierarchy.md](references/source-hierarchy.md) before resolving conflicts. Read [smartthings-edge-patterns.md](references/smartthings-edge-patterns.md) before choosing profiles, components, children, capabilities, or test shape.
6. Compare the matrix with existing local drivers. Reuse an existing pattern only when the endpoint topology and feature semantics match.
7. Implement only features supported by evidence. Add an explicit model-scoped gap for unsupported, ambiguous, or platform-inexpressible features.
8. Add regression tests for fingerprint selection, endpoint routing, feature writes, and reports/events affected by the change.

## Evidence Record

Include this compact record in the implementation handoff or PR description:

```text
Model: <manufacturer> / <zigbee model> / <product model and region>
Sources: <device page>, <converter definition>, <shared helpers>, <local analogue>
Endpoints: <endpoint matrix summary>
Supported: <implemented controls, settings, telemetry, actions>
Deferred: <feature and evidence/reason>
Tests: <new and executed tests>
```

Do not describe a feature as supported merely because a similarly named model supports it. Record the evidence link or local path that establishes each nonstandard behavior.

## Reference Selection

- Read [source-hierarchy.md](references/source-hierarchy.md) for authoritative sources and lookup paths.
- Read [smartthings-edge-patterns.md](references/smartthings-edge-patterns.md) for this repository's implementation conventions.
- Read [worked-examples.md](references/worked-examples.md) only when an endpoint or feature classification example is useful. Examples illustrate the method; they are not defaults for other models.
- For Aqara/Xiaomi manufacturer attributes, also read `skills/aqara-custom-clusters/SKILL.md` and validate every attribute against the target model.
