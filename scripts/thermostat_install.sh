#!/usr/bin/env bash
set -euo pipefail
CHANNEL_ID="609e2190-c8fa-4b9a-9986-62367890277e"
HUB_ID="7ac1150a-dd20-454d-9a4c-cd4cd5ed274d"
DRIVER_ID="07907e5a-5b8b-4e32-93f0-c0572e4aea60"
ST_BIN="$(command -v smartthings)"
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/zigbee-thermostat"
"$ST_BIN" edge:drivers:package .
"$ST_BIN" edge:channels:assign "$DRIVER_ID" --channel "$CHANNEL_ID"
"$ST_BIN" edge:drivers:install "$DRIVER_ID" --channel "$CHANNEL_ID" --hub "$HUB_ID"
