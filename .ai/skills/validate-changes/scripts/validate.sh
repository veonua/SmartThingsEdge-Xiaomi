#!/usr/bin/env bash
set -euo pipefail

root="${1:-.}"
cd "$root"

lua_files=()
drivers=()
while IFS= read -r file; do
  [[ "$file" == *.lua && -f "$file" ]] || continue
  lua_files+=("$file")
  if [[ "$file" == */src/* ]]; then
    driver="${file%%/src/*}"
    [[ -d "$driver/src/test" ]] && drivers+=("$driver")
  fi
done < <(
  {
    git diff --name-only
    git diff --cached --name-only
    git ls-files --others --exclude-standard
  } | awk 'NF && !seen[$0]++'
)

if ((${#lua_files[@]} == 0)); then
  echo "No changed Lua files to validate."
  exit 0
fi

command -v luac >/dev/null || { echo "Missing required compiler: luac" >&2; exit 127; }
command -v luacheck >/dev/null || { echo "Missing required linter: luacheck" >&2; exit 127; }

printf 'Compiling %s changed Lua file(s)\n' "${#lua_files[@]}"
luac -p "${lua_files[@]}"

printf 'Linting %s changed Lua file(s)\n' "${#lua_files[@]}"
luacheck "${lua_files[@]}"

if ((${#drivers[@]} == 0)); then
  echo "No affected driver test directory found."
  exit 0
fi

if ! command -v busted >/dev/null; then
  echo "Skipping tests: busted is not installed." >&2
  exit 0
fi

tested_drivers='|'
for driver in "${drivers[@]}"; do
  case "$tested_drivers" in
    *"|$driver|"*) continue ;;
  esac
  tested_drivers="${tested_drivers}${driver}|"
  echo "Testing $driver/src/test"
  busted "$driver/src/test"
done