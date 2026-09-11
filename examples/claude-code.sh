#!/usr/bin/env bash
# Non-interactive smoke test: ask the agent to enumerate the Agent Handler tool
# catalog. Useful for confirming the kit, the MCP registration, and the network
# policy all line up before doing real work.
set -euo pipefail

KIT_REF="${KIT_REF:-./}"
SERVER_NAME="${SERVER_NAME:-merge}"

if ! sbx mcp ls | awk '{print $1}' | grep -qx "$SERVER_NAME"; then
  echo "MCP server '$SERVER_NAME' is not registered. Run:" >&2
  echo "  sbx mcp add $SERVER_NAME --url https://ah-api.merge.dev/mcp" >&2
  exit 1
fi

sbx run claude \
  --kit "$KIT_REF" \
  --static-mcp "$SERVER_NAME" \
  -- \
  -p "List the tools the Merge Agent Handler MCP server exposes, grouped by the
      system they belong to. Do not attempt to authenticate to any third-party
      system yourself."
