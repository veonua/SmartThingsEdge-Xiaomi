---
name: validate-changes
description: Select and run proportionate validation for repository changes. Use after implementing or reviewing code, configuration, test, or documentation changes when the appropriate checks must be inferred from repository guidance, changed files, and available tooling.
---

# Validate Changes

Inspect repository instructions, project metadata, and the changed-file list before choosing checks. Execute a compiler or syntax check, linter, and targeted test suite whenever the changed language and repository tooling support them.

## Workflow

1. Read applicable `AGENTS.md`, contribution guidance, and declared test or build scripts.
2. Inspect the diff and identify each affected language, framework, and generated artifact.
3. Run the narrowest compiler or syntax check, linter, and targeted tests that exercise the edited code. Do not treat inspection alone as validation.
4. Expand to suite or repository-wide checks only when the change has broad impact, targeted validation is unavailable, or repository instructions require it.
5. Distinguish introduced failures from known baseline failures. Report the command, result, and scope.

## Rules

- Prefer project-provided commands over invented equivalents.
- Do not modify source files solely to satisfy formatting or linting unless that work is within scope.
- If a required tool is unavailable, state that the check was skipped and name the missing tool.
- For documentation-only changes, validate links, syntax, and relevant repository conventions instead of running unrelated code suites.
- Avoid destructive cleanup commands and do not broaden validation merely to produce a green result.

## Lua repositories

Run `bash ./scripts/validate-lua-changes.sh [repository-root]`. The script finds changed and untracked Lua files, compiles them with `luac -p`, lints them with `luacheck`, and runs `busted` for each affected driver's `src/test` directory. It reports when no test directory is affected or `busted` is unavailable.
