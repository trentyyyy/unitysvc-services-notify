#!/bin/bash
# GATEWAY_SRC points to apisix-gateways/src with #91's normalization helpers.
set -euo pipefail
: "${GATEWAY_SRC:?Set GATEWAY_SRC to an apisix-gateways/src checkout}"
repo=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo"
python3 - <<'PY'
import base64
from pathlib import Path
root=Path('services/templates/msg-to-discord')
assert base64.b64decode((root/'discord-body.base64').read_text()) == (root/'discord-body.lua').read_bytes(), 'Regenerate discord-body.base64 from discord-body.lua'
PY
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
usvc_seller specs expand labs/msg-to-discord --flat --output-dir "$scratch"
docker run --rm -v "$repo/tests:/tests:ro" -v "$scratch/offering.json:/offering.json:ro" \
  -v "$GATEWAY_SRC:/gateway:ro" -e DISCORD_OFFERING=/offering.json \
  -e 'LUA_PATH=/usr/local/apisix/deps/share/lua/5.1/?.lua;;' \
  apache/apisix:3.17.0-debian resty /tests/test_discord_marker.lua
