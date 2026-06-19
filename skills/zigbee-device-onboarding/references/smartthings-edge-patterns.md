# SmartThings Edge Patterns

## Device Identity and Profile

- Put exact join strings in the driver’s `fingerprints.yml`; manufacturer names are case-sensitive.
- Select a profile based on actual endpoints and exposed SmartThings capabilities, not product marketing terms.
- Add a dedicated profile when an existing profile would expose a command on an endpoint that does not implement it.

## Endpoints and Children

- Map every relay/control endpoint to a component or an Edge child device.
- Use a button-only child for an action-only endpoint; never expose `switch` for a wireless-only endpoint.
- Persist discovered endpoint offsets only when the driver must derive component routing at runtime.
- Test parent-to-child routing for both reports and commands.

## Capabilities, Preferences, and Telemetry

- Use standard SmartThings capabilities when their value and unit match the device data.
- Model writable configuration as profile preferences and translate changes with explicit endpoint, cluster, attribute, manufacturer code, and data type.
- Treat private cluster IDs and values as model-scoped. Read before write when protocol evidence is incomplete.
- Parse telemetry only after confirming scaling and units. Keep platform-inexpressible diagnostics in fields/logging and state the limitation in the evidence record.

## Validation

- Add a mock descriptor containing the target manufacturer, model, endpoint IDs, and server clusters.
- Cover fingerprint/profile selection, relay command routing, report/action routing, preference writes, and telemetry conversion for every newly added behavior.
- Run the affected driver tests and package validation. Preserve unrelated worktree changes.
