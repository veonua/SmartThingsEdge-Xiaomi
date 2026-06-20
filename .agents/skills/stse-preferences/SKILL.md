# STSE Preference Skill

Purpose: quick reference for standard `stse.*` profile preferences used by SmartThings Edge drivers, with examples you can paste into profile YAML.

Scope note: this list is built from:
- This repository profile files
- `SmartThingsCommunity/SmartThingsEdgeDrivers` profile files (`preferenceId: stse.*`)

## Quick Usage

Add preferences to a profile `preferences:` block as:

```yml
preferences:
  - preferenceId: stse.restorePowerState
    explicit: true
  - preferenceId: stse.turnOffIndicatorLight
    explicit: true
```

## STSE Preferences Catalog

This section adds practical meaning and known options for each preference.

### Switch / Plug / Light

| Preference | What it does | Known options | Source |
|---|---|---|---|
| `stse.restorePowerState` | Sets power-on restore behavior after power loss. | `true` / `false` | Local Xiaomi switch/plug handlers; upstream `zigbee-switch` preference map |
| `stse.turnOffIndicatorLight` | Controls indicator LED behavior. Some device models invert internal payload logic. | `true` / `false` | Local Xiaomi switch/plug handlers; upstream `zigbee-switch` |
| `stse.changeToWirelessSwitch` | Enables decoupled/wireless mode (relay behavior changes, button events only). | `true` / `false` | Local Xiaomi switch handler (writes attr `0x0200`), upstream `zigbee-switch` |
| `stse.electricSwitchType` | Selects physical switch mode for compatible Aqara modules. | `rocker`, `rebound` | Upstream `zigbee-switch/src/aqara/init.lua` value map |
| `stse.maxPower` | Over-power threshold (trip/protect threshold). | String values `"1"`..`"25"` (mapped to manufacturer float payload) | Upstream `zigbee-switch/src/aqara/init.lua` value map |
| `stse.maxPowerCN` | China variant of over-power threshold. | Usually same coded range as `stse.maxPower` (`"1"`..`"25"`) | Local plug/switch writes float to attr `0x020B`; upstream Aqara map |

### Button / Knob

| Preference | What it does | Known options | Source |
|---|---|---|---|
| `stse.allowOperationModeChange` | Allows runtime mode switching on certain Aqara button remotes (Press button 5 times to change operation mode Thread/Zigbee). | `true` / `false` | Upstream `zigbee-button/src/aqara/init.lua` |
| `stse.knobSensitivity` | Rotation sensitivity multiplier for knob delta events. | `1`, `2`, `3` (mapped to factors `0.5`, `1.0`, `2.0`) | Upstream `zigbee-button/src/aqara-knob/init.lua` |

### Presence / Motion

| Preference | What it does | Known options | Source |
|---|---|---|---|
| `stse.sensitivity` | Presence sensor sensitivity level written to private attr `0x010C`. | Numeric level, typically `1`..`3` | Upstream FP1 handler/tests |
| `stse.resetPresence` | Triggers presence-state reset action (write reset flag) when changed. | Treated as trigger; `true` causes write, `false` typically no-op | Upstream FP1 handler/tests |

### Window Treatment

| Preference | What it does | Known options | Source |
|---|---|---|---|
| `stse.reverseCurtainDirection` | Reverses open/close direction mapping. | `true` / `false` | Upstream Aqara window-treatment handlers/tests |
| `stse.softTouch` | Toggles soft-touch/manual-control behavior for Aqara curtain drivers. | `true` / `false` | Upstream Aqara window-treatment handlers/tests |
| `stse.reverseRollerShadeDir` | Reverses roller shade direction on compatible Aqara roller shade models. | Expected boolean (`true` / `false`) | Upstream profiles and roller-shade code usage |

### Thermostat

| Preference | What it does | Known options | Source |
|---|---|---|---|
| `stse.notificationOfValveTest` | Enables/disables valve-test notification behavior. | `true` / `false` (mapped to `0x01` / `0x00`) | Upstream Aqara thermostat preference map/tests |
| `stse.antifreezeModeSetting` | Sets antifreeze temperature setting. Driver converts value with `value * 50 + 450` before write. | Numeric/string number from preference UI (device/profile specific) | Upstream Aqara thermostat preference map |

### Other Aqara Device Preferences

| Preference | What it does | Known options | Source |
|---|---|---|---|
| `stse.buttonLock` | Locks/unlocks physical feed button on Aqara feeder. | `true` / `false` | Upstream Aqara feeder handler |
| `stse.nightLightMode` | Controls bath-heater night-light operating mode. | Device-specific mode values (profile-defined) | Upstream Aqara bath-heater handler |
| `stse.nightLightStartTime` | Start time for night-light schedule. | Device/profile-defined time format | Upstream Aqara bath-heater handler |

## Copy/Paste Blocks

### Typical switch prefs

```yml
preferences:
  - preferenceId: stse.restorePowerState
    explicit: true
  - preferenceId: stse.turnOffIndicatorLight
    explicit: true
```

### Switch with decoupled mode

```yml
preferences:
  - preferenceId: stse.changeToWirelessSwitch
    explicit: true
  - preferenceId: stse.restorePowerState
    explicit: true
```

### Aqara curtain / blind prefs

```yml
preferences:
  - preferenceId: stse.reverseCurtainDirection
    explicit: true
  - preferenceId: stse.softTouch
    explicit: true
```

### Motion/presence tuning prefs

```yml
preferences:
  - preferenceId: stse.sensitivity
    explicit: true
  - preferenceId: stse.resetPresence
    explicit: true
```

## Discovery Workflow

Use these commands to discover newly added standard preferences in upstream drivers.

1) Search upstream profile preference IDs:

```bash
gh api \
  /search/code \
  -f q='"preferenceId: stse." repo:SmartThingsCommunity/SmartThingsEdgeDrivers' \
  --jq '.items[].path'
```

2) Extract unique IDs from your local repository:

```bash
find . -type f \( -name "*.yml" -o -name "*.yaml" \) -print0 \
  | xargs -0 grep -h -Eo "preferenceId:[[:space:]]*stse\.[A-Za-z0-9_]+" \
  | sed -E 's/.*stse\./stse./' \
  | sort -u
```

3) Keep a delta list (upstream minus local) when adding support for new devices.

## Validation Checklist

- Preference is listed under `preferences:` with `explicit: true`
- Driver implements handling for that preference in Lua (`infoChanged` or equivalent)
- Preference is applicable to the fingerprinted device model
- UI behavior is verified in SmartThings app