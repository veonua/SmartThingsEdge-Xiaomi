# Aqara Custom Clusters Skill

Purpose: practical reverse-engineering reference for Aqara/Xiaomi manufacturer-specific Zigbee attributes, centered on cluster `0xFCC0` (Lumi private cluster), with concrete meanings and option maps.

Scope note:
- This is a best-known map assembled from SmartThings Edge drivers, zigbee-herdsman-converters, and local Xiaomi Edge code.
- Aqara firmware varies by model and region. Same attribute ID can behave differently across product lines.

## Main Sources

Primary references used for this skill:

1. SmartThings Community Edge Drivers (upstream)
  - https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers
  - Aqara switch private attrs and `stse.*` mappings: https://raw.githubusercontent.com/SmartThingsCommunity/SmartThingsEdgeDrivers/main/drivers/SmartThings/zigbee-switch/src/aqara/init.lua
  - Aqara thermostat private attrs (`0x027x` family): https://raw.githubusercontent.com/SmartThingsCommunity/SmartThingsEdgeDrivers/main/drivers/SmartThings/zigbee-thermostat/src/aqara/init.lua
  - Aqara window treatment private cluster helpers: https://raw.githubusercontent.com/SmartThingsCommunity/SmartThingsEdgeDrivers/main/drivers/SmartThings/zigbee-window-treatment/src/aqara/aqara_utils.lua
  - Aqara bath-heater constants (`0xFCC0` attrs): https://raw.githubusercontent.com/SmartThingsCommunity/SmartThingsEdgeDrivers/main/drivers/Aqara/aqara-bath-heater/src/aqara_cluster.lua

2. Zigbee2MQTT converter stack (broad model coverage)
  - https://github.com/Koenkk/zigbee-herdsman-converters
  - Core Lumi private cluster logic, attr decoding, modern extensions: https://raw.githubusercontent.com/Koenkk/zigbee-herdsman-converters/master/src/lib/lumi.ts
  - Device-to-attribute usage across Aqara models: https://raw.githubusercontent.com/Koenkk/zigbee-herdsman-converters/master/src/devices/lumi.ts

3. This repository (implementation reality check)
  - [xiaomi_utils.lua](xiaomi_utils.lua)
  - [xiaomi-switch/src/opple/init.lua](xiaomi-switch/src/opple/init.lua)
  - [xiaomi-switch/src/init.lua](xiaomi-switch/src/init.lua)
  - [xiaomi-plug/src/init.lua](xiaomi-plug/src/init.lua)
  - [zigbee-motion-sensor/src/lumi/init.lua](zigbee-motion-sensor/src/lumi/init.lua)

Source quality heuristic used:
- Highest trust: direct write/read implementations with explicit attribute IDs and manufacturer code.
- Next: converter/expose mappings validated across multiple device definitions.
- Lower: inferred behavior from naming alone without explicit write/read path.

## Core Identity

- Manufacturer code: `0x115F` (Lumi/Aqara)
- Main private cluster: `0xFCC0` (`manuSpecificLumi`, `AqaraOpple`)
- Related private attributes may also appear under:
  - `genBasic` (`0x0000`) attributes like `0xFFF0`, `0xFF22`
  - nested/packed payload attributes like `0x00F7`, `0xFFF1`, `0xFFF2`, `0xFFFA`

## Quick Write Pattern

SmartThings Edge Lua (manufacturer-specific write):

```lua
device:send(cluster_base.write_manufacturer_specific_attribute(
  device,
  0xFCC0,      -- cluster
  0x0201,      -- attribute
  0x115F,      -- manufacturer code
  data_types.Boolean,
  true
))
```

zigbee-herdsman (same idea):

```ts
await endpoint.write(
  "manuSpecificLumi",
  {0x0201: {value: 1, type: 0x10}},
  {manufacturerCode: 0x115f}
);
```

## High-Confidence Attribute Dictionary

These mappings are repeatedly confirmed in upstream drivers and converters.

| Attr (hex/dec) | Type | Meaning | Known options/values | Confidence |
|---|---|---|---|---|
| `0x0004` / `4` | `UINT16` | Switch mode (speed/flicker mode). | `1=quick_mode`, `4=anti_flicker_mode` | High |
| `0x0009` / `9` | `UINT8` | Operation mode selector used by many wall switches/remotes (`command` vs `event`). | Typically `0=command`, `1=event` | High |
| `0x000A` / `10` | `UINT8` | External switch type. | `1=toggle`, `2=momentary` (some stacks also show `3=none`) | High |
| `0x00F0` / `240` | `UINT8` | Flip indicator logic. | `0=OFF`, `1=ON` | High |
| `0x0102` / `258` | `UINT8`/`UINT16` | Detection interval (motion-related). | Seconds, model constrained | High |
| `0x010C` / `268` | `UINT8` | Sensitivity/config axis used by presence/motion and gas stacks. | Often `1=low`, `2=medium`, `3=high` | High |
| `0x0125` / `293` | `UINT8` | Click mode (wireless switches/buttons). | `1=fast`, `2=multi` | High |
| `0x0142` / `322` | `UINT8` | Presence state on FP-series sensors. | `0/1`, sometimes `255=null` | High |
| `0x0146` / `326` | `UINT8` | Presence approach distance mode. | `0=far`, `1=medium`, `2=near` | High |
| `0x0150` / `336` | `OCTET_STR` | FP1 region config write payload. | Structured bytes (create/modify/delete region) | High |
| `0x0151` / `337` | `UINT8`/`struct` | FP1 region event channel. | enter/leave/occupied/unoccupied event encoding | High |
| `0x0152` / `338` | `UINT8` | Trigger indicator LED for motion sensors. | `0/1` | High |
| `0x0200` / `512` | `UINT8` | Operation mode / decoupled relay mode. | `0=decoupled`, `1=control_relay` (model-dependent endpoint scoping) | High |
| `0x0201` / `513` | `BOOL`/`UINT8` | Power outage memory / restore power state. | `0/1` off/on; some products expose enum variants elsewhere | High |
| `0x0202` / `514` | `BOOL` | Auto-off or charging-protection style toggle (model dependent). | `0/1` | Medium |
| `0x0203` / `515` | `BOOL` | LED indicator behavior (`led_indicator` / `led_disabled_night` depending model). | `0/1`; interpretation may invert in specific firmware | High |
| `0x0206` / `518` | `SINGLE_PREC` | Charging power limit on certain outlets. | Numeric watts, model range-specific | Medium |
| `0x020B` / `523` | `SINGLE_PREC` | Overload protection threshold. | Numeric watts (e.g., ~100-3840 depending device) | High |
| `0x0285` / `645` | `UINT8` | Relay lock. | `0/1` unlock/lock | High |
| `0x0286` / `646` | `UINT8` | KD-R01D/H2 off-state event mode selector (button/knob behavior while relay output is off). | `1=single press oriented`, `2=multi-click + knob events` | High |

## Thermostat/Valve Private IDs (Aqara TRV Family)

| Attr (hex/dec) | Meaning | Known options/values | Confidence |
|---|---|---|---|
| `0x0270` / `624` | Start valve calibration | write trigger (`1`) | High |
| `0x0271` / `625` | System mode | `0=off`, `1=heat` (some newer stacks add auto behavior by composition) | High |
| `0x0272` / `626` | Preset/operating mode | values vary by model (`manual/auto/away` families) | High |
| `0x0273` / `627` | Window detection | `0/1` | High |
| `0x0274` / `628` | Valve/temperature abnormal notification switch | `0/1` | High |
| `0x0275` / `629` | Alarm information | non-zero indicates alarm states | Medium |
| `0x0276` / `630` | Schedule blob | encoded schedule bytes | High |
| `0x0277` / `631` | Child lock | `0=unlock`, `1=lock` | High |
| `0x0279` / `633` | Antifreeze setpoint | scaled temperature (commonly centi-degrees) | High |
| `0x027B` / `635` | Calibration result/status | `0=pending`, `1=success`, `2=failure` (model variations exist) | High |
| `0x027D` / `637` | Schedule enabled | `0/1` | High |
| `0x027E` / `638` | Sensor source | internal/external mode enum | High |
| `0x0280` / `640` | Sensor binding/source variant | often internal/external selector paths | Medium |

## Curtain / Cover IDs on 0xFCC0

| Attr | Meaning | Known options | Confidence |
|---|---|---|---|
| `0x0400` | Curtain reverse direction | boolean | High |
| `0x0401` | Hand-open (manual pull) behavior | boolean | High |
| `0x0402` | Calibrated flag | boolean | High |
| `0x0403` | Traverse time | seconds | High |
| `0x0404` | Identify beep duration | enum (`short`, `1_sec`, `2_sec`) | Medium |
| `0x0408` | Motor speed | `low/medium/high` | High |
| `0x041F` | Curtain position | percent-ish state value | Medium |
| `0x0421` | Curtain status | `closing/opening/stopped/blocked` families | Medium |
| `0x0425` | Last manual operation | `open/close/stop` | Medium |
| `0x0426` | Calibration status | `not/half/fully calibrated` variants | Medium |
| `0x043A` | Manual stop toggle | boolean | Medium |
| `0x043B` | Curtain speed | numeric | Medium |
| `0x0442` | Adaptive pulling speed | boolean | Medium |

## Lighting-Focused 0xFCC0 IDs (newer Aqara lights)

| Attr | Meaning | Known options | Confidence |
|---|---|---|---|
| `0x0515` | Minimum dimming/brightness | numeric | High |
| `0x0516` | Maximum dimming/brightness | numeric | High |
| `0x0517` | Power-on behavior enum | commonly `on/previous/off/...` by model | High |
| `0x051B` | Strip length (segment model specific) | numeric | Medium |
| `0x051C` | Audio sync mode | bool/enum | Medium |
| `0x051D` | Audio effect enum | model-specific effect set | Medium |
| `0x051E` | Audio sensitivity | enum | Medium |
| `0x051F` | RGB dynamic effect | enum | High |
| `0x0520` | RGB effect speed | numeric percent | High |
| `0x0528` | Transition curvature | float-like tuning parameter | Medium |
| `0x052C` | Initial transition brightness | numeric | Medium |

## Packed/Meta Attributes You Will See Often

| Attr | Where | Meaning | Confidence |
|---|---|---|---|
| `0x00F7` (`247`) | `0xFCC0` | Heartbeat-like packed telemetry (contains nested key/value set). Often includes temp, outage count, firmware hints. | High |
| `0x00FF` (`65281`) | `genBasic` or decoded path | Xiaomi/Lumi struct payload (device stats, voltage, temp, etc.). | High |
| `0xFF22` | `genBasic` | Legacy operation-mode attribute for older wall switches. | High |
| `0xFFF0` (`65520`) | `genBasic` | Legacy opaque command payload channel on older models. | High |
| `0xFFF1` (`65521`) | `0xFCC0` | Command-like packed write channel used by feeder/toilet and similar appliances. | High |
| `0xFFF2` (`65522`) | `0xFCC0` | Advanced binary transport payload used for sensor binding/config and feature tunnels on modern devices. | High |

## Aqara Bath Heater (0xFCC0) Known IDs

Observed in SmartThings Aqara bath-heater cluster constants:

| Attr | Meaning | Confidence |
|---|---|---|
| `0x024F` | AC code field | Medium |
| `0x0256` | DND beep control | Medium |
| `0x0257` | DND time | Medium |
| `0x02BE` | Thermostat control switch | Medium |
| `0x0518` | Night light | Medium |

## Attribute Collision Warning

Aqara reuses IDs across product families, and semantics can diverge. For example:
- `0x0203` may mean LED indicator, LED disabled at night, or inverted presentation depending firmware/product.
- `0x010C` appears for motion/presence sensitivity and also in gas-related paths.
- `0x027x` range is heavily thermostat-centric but variant-specific encoding differs (TRV E1 vs W500/W600 lines).

Always pair interpretation with exact model fingerprint.

## Model-Scoped Validation Flow

1. Read current value before writing:

```lua
device:send(cluster_base.read_manufacturer_specific_attribute(device, 0xFCC0, 0x0201, 0x115F))
```

2. Write candidate value and capture immediate report.
3. Refresh/re-read attribute to verify persistence.
4. Validate behavior in capability events (not just raw attribute ack).
5. Record model-specific mapping in driver code comments or a lookup table.

## Discovery Workflow (Deep Search)

Use these to expand this catalog when new devices appear:

1) SmartThings Edge Aqara usage:

```bash
gh api /search/code -f q='0xFCC0 repo:SmartThingsCommunity/SmartThingsEdgeDrivers language:lua' --jq '.items[].path'
```

2) Zigbee2MQTT converter usage:

```bash
gh api /search/code -f q='manuSpecificLumi repo:Koenkk/zigbee-herdsman-converters language:ts' --jq '.items[].path'
```

3) Find attr IDs in local repository:

```bash
find . -type f \( -name "*.lua" -o -name "*.yml" -o -name "*.yaml" \) -print0 \
  | xargs -0 grep -nE '0xFCC0|0x115F|0x0[0-9A-Fa-f]{3}|0xF{3}[0-9A-Fa-f]'
```

## Practical Notes For This Repo

- Local handlers already write key switch attrs on `0xFCC0`: `0x0200`, `0x0201`, `0x0203`, `0x020B`.
- KD-R01D (`lumi.switch.agl011`) uses `0x0286` for off-state event mode; code keeps `0x0125` writes for broader Opple compatibility.
- Preference mapping in this repo: `offStateEventMode` -> `0x0286`/`0x0125` with values `1` (single-oriented) and `2` (multi-click + knob while off).
- Motion path uses `0x010C` for sensitivity configuration.
- Some legacy/private operations still use `genBasic` payload channels (`0xFFF0`) in addition to `0xFCC0`.

## Confidence Legend

- High: confirmed by at least two independent sources or direct write/read implementation.
- Medium: confirmed by one strong source and/or clear naming context.
- Low: inferred from sparse evidence; validate before exposing to users.