#!/bin/bash
set -euo pipefail
: "${GATEWAY_SRC:?Set GATEWAY_SRC to an apisix-gateways/src checkout}"
repo=$(cd "$(dirname "$0")/.." && pwd)
docker run --rm -v "$repo/tests:/tests:ro" \
  -v "$repo/services/specs/labs/discord-to-msg:/service:ro" \
  -v "$GATEWAY_SRC:/gateway:ro" \
  -e 'LUA_PATH=/usr/local/apisix/deps/share/lua/5.1/?.lua;;' \
  apache/apisix:3.17.0-debian resty /tests/test_discord_inbound_marker.lua
