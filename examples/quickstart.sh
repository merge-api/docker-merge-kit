#!/usr/bin/env bash
# Register Merge Agent Handler on the host, then launch an interactive sandbox
# with the kit applied.
#
# Usage: ./examples/quickstart.sh [workspace-path]
set -euo pipefail

KIT_REF="${KIT_REF:-./}"
SERVER_NAME="${SERVER_NAME:-merge}"
WORKSPACE="${1:-.}"

# `sbx mcp add` is idempotent enough to re-run, but skip it when the server is
# already registered so we don't trigger a fresh OAuth consent every launch.
if sbx mcp ls | awk '{print $1}' | grep -qx "$SERVER_NAME"; then
  echo "MCP server '$SERVER_NAME' already registered; skipping add."
else
  echo "Registering '$SERVER_NAME' — a browser window will open for consent."
  sbx mcp add "$SERVER_NAME" --url https://ah-api.merge.dev/mcp
fi

echo "Launching sandbox with the Merge Agent Handler kit..."
exec sbx run claude \
  --kit "$KIT_REF" \
  --static-mcp "$SERVER_NAME" \
  "$WORKSPACE"
