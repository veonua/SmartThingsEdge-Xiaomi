# AGENTS

## Purpose
This file provides working guidance for coding agents contributing to this repository.

## Repository Overview
This repository contains multiple SmartThings Edge drivers and related integrations.


## Validation
After edits, run the narrowest relevant validation available for the files changed. Prefer
repository-provided checks and targeted tests over repository-wide scans. Record any skipped
check, missing tool, or pre-existing baseline failure in the handoff. Use the
`$validate-changes` skill when available to select and run the appropriate checks.

## Testing
- Preferred Lua test runner is busted when available.
- If busted is not installed, report that tests were skipped due to missing tool.

## Change Quality Expectations
- Keep diffs minimal and localized.
- Preserve existing naming and style patterns unless a change request asks otherwise.
- Include only behavior supported by model evidence.
- If uncertain about device capabilities, document assumptions and avoid overexposing unsupported features.

## Documentation
When behavior decisions are non-obvious, add a short rationale in:
- .ai/lessons-learned.md
