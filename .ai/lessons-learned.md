# Lessons Learned

1. Separate identity from behavior.
- Fingerprint confirms matching manufacturer and model.
- Endpoint topology and capabilities determine the implementation.

2. Let endpoint evidence drive profile shape.
- For ZNQBKG41LM (lumi.switch.acn055), endpoints 1-3 are relay channels.
- Endpoint 4 is wireless-only and should be button-only, not switch.

3. Avoid redundant config groups.
- If two groups have the same `first_button_ep` and `supported_button_values`, merge them.
- Add a new group only when behavior or defaults differ.

4. Add explicit model handling when pattern parsing is insufficient.
- `lumi.switch.acn055` needs explicit channel metadata (`number_of_channels = 3`).
- This prevents endpoint-to-component routing mistakes.

5. Validate both structure and behavior.
- Run syntax/schema diagnostics after edits.
- Add regression tests for fingerprint selection and endpoint mapping.
