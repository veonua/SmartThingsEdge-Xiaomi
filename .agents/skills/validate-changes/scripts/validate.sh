#!/usr/bin/env bash
set -euo pipefail

root="${1:-.}"
cd "$root"
smartthings_lua_libs="${SMARTTHINGS_LUA_LIBS:-$root/lua_libs}"

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

if ! command -v lua >/dev/null; then
  echo "Skipping tests: lua is not installed." >&2
  exit 0
fi

if [[ ! -d "$smartthings_lua_libs/st" || ! -d "$smartthings_lua_libs/integration_test" ]]; then
  echo "Skipping tests: SmartThings lua libs were not found at $smartthings_lua_libs." >&2
  exit 0
fi

lua_path="${smartthings_lua_libs}/?.lua;${smartthings_lua_libs}/?/init.lua;./?.lua;./?/init.lua;;"

tested_drivers='|'
for driver in "${drivers[@]}"; do
  case "$tested_drivers" in
    *"|$driver|"*) continue ;;
  esac
  tested_drivers="${tested_drivers}${driver}|"
  echo "Testing $driver/src/test"
  while IFS= read -r test_file; do
    (
      cd "$driver/src"
      local_test_file="${test_file#"$driver/src/"}"
      LUA_PATH="$lua_path" lua "$local_test_file"
    )
  done < <(find "$driver/src/test" -maxdepth 1 -type f -name 'test_*.lua' | sort)
done
