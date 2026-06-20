# Worked Examples

Examples demonstrate evidence capture, not reusable device behavior.

## Aqara Z1 Four-Key: `ZNQBKG41LM`

Evidence sources:

- [Zigbee2MQTT device page](https://www.zigbee2mqtt.io/devices/ZNQBKG41LM.html)
- [upstream Lumi device definition](https://github.com/Koenkk/zigbee-herdsman-converters/blob/master/src/devices/lumi.ts)
- [upstream Lumi helpers](https://github.com/Koenkk/zigbee-herdsman-converters/blob/master/src/lib/lumi.ts)

Findings:

- Fingerprint identity is `Aqara` / `lumi.switch.acn055`; product model is `ZNQBKG41LM`.
- Endpoints 1–3 are relay controls (`top`, `center`, `bottom`); endpoint 4 is a wireless-only button.
- The device page lists user-visible controls and telemetry. The converter establishes endpoint names, action values, and manufacturer-specific settings.
- A SmartThings design must give endpoint 4 a button-only representation. It must not give it a switch command.
- Standard telemetry maps to standard SmartThings capabilities where units match. The power-outage counter can remain diagnostic-only if no suitable capability is desired.

This example does not establish endpoint numbering, attribute meanings, or capability choices for other Z1 variants or Aqara models.

## Generic Evidence Record

For a new model, record the result before coding:

```text
Model: Vendor / Zigbee model / commercial model
Endpoints: 1=relay (OnOff), 2=action-only (Multistate Input)
Settings: endpoint 1, manufacturer cluster <id>, attribute <id>, type <type>
Telemetry: cluster/attribute <id>, raw scale <n>, capability <id>, unit <unit>
Deferred: <feature> because <missing target-model evidence or platform limitation>
```
