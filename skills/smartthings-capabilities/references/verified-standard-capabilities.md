# Verified Capabilities Used by This Repository

Fetched from the live registry with `smartthings capabilities <id> --standard --json` (standard) or `smartthings capabilities <id> --json` (custom). Refresh before relying on a contract.

## Standard

| Capability | V | Attributes | Commands |
|---|---:|---|---|
| `airConditionerFanMode` | 1 | `fanMode`, `supportedAcFanModes`, `availableAcFanModes` | `setFanMode` |
| `airConditionerMode` | 1 | `availableAcModes`, `supportedAcModes`, `airConditionerMode` | `setAirConditionerMode` |
| `atmosphericPressureMeasurement` | 1 | `atmosphericPressure` | — |
| `battery` | 1 | `quantity`, `battery`, `type` | — |
| `batteryLevel` | 1 | `quantity`, `battery`, `type` | — |
| `button` | 1 | `button`, `numberOfButtons`, `supportedButtonValues` | — |
| `colorControl` | 1 | `saturation`, `color`, `hue` | `setColor`, `setHue`, `setSaturation` |
| `colorTemperature` | 1 | `colorTemperatureRange`, `colorTemperature` | `setColorTemperature` |
| `configuration` | 1 | — | `configure` |
| `contactSensor` | 1 | `contact` | — |
| `currentMeasurement` | 1 | `current` | — |
| `energyMeter` | 1 | `energy` | `resetEnergyMeter` |
| `firmwareUpdate` | 1 | `lastUpdateStatusReason`, `imageTransferProgress`, `availableVersion`, `lastUpdateStatus`, `supportedCommands`, `state`, `estimatedTimeRemaining`, `updateAvailable`, `currentVersion`, `lastUpdateTime`, `supportsProgressReports` | `updateFirmware`, `checkForFirmwareUpdate` |
| `illuminanceMeasurement` | 1 | `illuminance` | — |
| `knob` | 1 | `rotateAmount`, `supportedAttributes`, `heldRotateAmount` | — |
| `mediaPresets` | 1 | `presets` | `playPreset` |
| `momentary` | 1 | — | `push` |
| `motionSensor` | 1 | `motion` | — |
| `powerConsumptionReport` | 1 | `powerConsumption` | — |
| `powerMeter` | 1 | `power` | — |
| `powerSource` | 1 | `powerSource` | — |
| `presenceSensor` | 1 | `presence` | — |
| `refresh` | 1 | — | `refresh` |
| `relativeHumidityMeasurement` | 1 | `humidity` | — |
| `robotCleanerCleaningMode` | 1 | `robotCleanerCleaningMode` | `setRobotCleanerCleaningMode` |
| `robotCleanerMovement` | 1 | `robotCleanerMovement` | `setRobotCleanerMovement` |
| `robotCleanerTurboMode` | 1 | `robotCleanerTurboMode` | `setRobotCleanerTurboMode` |
| `signalStrength` | 1 | `rssi`, `lqi` | — |
| `smokeDetector` | 1 | `smoke` | — |
| `statelessPowerToggleButton` | 1 | `availablePowerToggleButtons` | `setButton` |
| `statelessSwitchLevelStep` | 1 | — | `stepLevel` |
| `switch` | 1 | `switch` | `on`, `off` |
| `switchLevel` | 1 | `levelRange`, `level` | `setLevel` |
| `temperatureAlarm` | 1 | `temperatureAlarm` | — |
| `temperatureMeasurement` | 1 | `temperatureRange`, `temperature` | — |
| `thermostatCoolingSetpoint` | 1 | `coolingSetpointRange`, `coolingSetpoint` | `setCoolingSetpoint` |
| `thermostatHeatingSetpoint` | 1 | `heatingSetpoint`, `heatingSetpointRange` | `setHeatingSetpoint` |
| `thermostatMode` | 1 | `thermostatMode`, `supportedThermostatModes` | `auto`, `cool`, `emergencyHeat`, `heat`, `off`, `setThermostatMode` |
| `thermostatOperatingState` | 1 | `supportedThermostatOperatingStates`, `thermostatOperatingState` | — |
| `voltageMeasurement` | 1 | `voltage` | — |
| `waterSensor` | 1 | `water` | — |
| `windowShade` | 1 | `supportedWindowShadeCommands`, `windowShade` | `close`, `open`, `pause` |
| `windowShadeLevel` | 1 | `shadeLevel` | `setShadeLevel` |
| `windowShadePreset` | 1 | `supportedCommands`, `position` | `setPresetPosition`, `presetPosition` |

## Custom

| Capability | V | Attributes | Commands |
|---|---:|---|---|
| `legendabsolute60149.atmosPressure` | 1 | `atmosPressure` | `setAtmosPressure` |
| `stse.cubeAction` | 1 | `cubeAction` | — |
| `stse.cubeFace` | 1 | `cubeFace` | — |
| `stse.deviceInitialization` | 1 | `supportedInitializedState`, `initializedState` | `setInitializedState` |
| `winterdictionary35590.cube` | 1 | `face`, `rotation`, `action` | — |

Verify allowed values, units, and command arguments with the registry before adding new use of any row.
