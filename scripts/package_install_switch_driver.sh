#!/usr/bin/env bash
set -euo pipefail

# Package + publish + install SmartThings Edge driver: Aqara/Xiaomi Switch and Button
# This script does NOT run automatically. Execute it manually when ready.
#
# Usage examples:
#   ./scripts/package_install_switch_driver.sh --channel-id 609e2190-c8fa-4b9a-9986-62367890277e
#   ./scripts/package_install_switch_driver.sh --channel-id <CHANNEL_ID> --hub-id <HUB_ID>
#   ./scripts/package_install_switch_driver.sh --channel-id <CHANNEL_ID> --driver-id <DRIVER_ID>

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIVER_DIR="$REPO_DIR/xiaomi-switch"
PACKAGE_KEY="lumi-switch"

CHANNEL_ID=""
HUB_ID=""
DRIVER_ID=""
ST_BIN=""

usage() {
  cat <<EOF
Usage: $0 --channel-id <id> [--hub-id <id>] [--driver-id <id>] [--smartthings-bin <path>]

Options:
  --channel-id      Edge channel UUID (required)
  --hub-id          Hub UUID (optional; uses CLI default if omitted)
  --driver-id       Driver UUID (optional; auto-detect by packageKey=$PACKAGE_KEY if omitted)
  --smartthings-bin Path to SmartThings CLI binary (optional)

Examples:
  $0 --channel-id 609e2190-c8fa-4b9a-9986-62367890277e
  $0 --channel-id <CHANNEL_ID> --hub-id <HUB_ID>
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --channel-id) CHANNEL_ID="${2:-}"; shift 2 ;;
    --hub-id) HUB_ID="${2:-}"; shift 2 ;;
    --driver-id) DRIVER_ID="${2:-}"; shift 2 ;;
    --smartthings-bin) ST_BIN="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$CHANNEL_ID" ]]; then
  echo "ERROR: --channel-id is required" >&2
  usage
  exit 1
fi

if [[ -z "$ST_BIN" ]]; then
  if command -v smartthings >/dev/null 2>&1; then
    ST_BIN="$(command -v smartthings)"
  elif [[ -x "$HOME/.npm/bin/smartthings" ]]; then
    ST_BIN="$HOME/.npm/bin/smartthings"
  else
    echo "ERROR: smartthings CLI not found. Install with: npm install -g @smartthings/cli" >&2
    exit 1
  fi
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required. Install with: brew install jq" >&2
  exit 1
fi

echo "Using SmartThings CLI: $ST_BIN"
"$ST_BIN" --version

cd "$DRIVER_DIR"

echo "==> Packaging driver from: $DRIVER_DIR"
"$ST_BIN" edge:drivers:package .

if [[ -z "$DRIVER_ID" ]]; then
  echo "==> Resolving driverId for packageKey=$PACKAGE_KEY"
  DRIVER_ID="$($ST_BIN edge:drivers --json | jq -r --arg k "$PACKAGE_KEY" '[.[] | select(.packageKey==$k)][0].driverId')"
fi

if [[ -z "$DRIVER_ID" || "$DRIVER_ID" == "null" ]]; then
  echo "ERROR: Could not determine DRIVER_ID. Provide --driver-id explicitly." >&2
  exit 1
fi

echo "Driver ID: $DRIVER_ID"
echo "Channel ID: $CHANNEL_ID"

echo "==> Publishing driver to channel"
"$ST_BIN" edge:drivers:publish "$DRIVER_ID" --channel "$CHANNEL_ID"

if [[ -n "$HUB_ID" ]]; then
  echo "==> Installing driver to hub: $HUB_ID"
  "$ST_BIN" edge:drivers:install "$DRIVER_ID" --hub "$HUB_ID"
else
  echo "==> Installing driver to default/selected hub"
  "$ST_BIN" edge:drivers:install "$DRIVER_ID"
fi

echo "Done."
