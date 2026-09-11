#!/usr/bin/env bash
# Non-interactive smoke test: ask the agent to enumerate the Agent Handler tool
# catalog and make one read-only call. Useful for confirming the kit, the MCP
# registration, the agent's own credential, and the network policy all line up.
#
# Note: this deliberately does NOT use `sbx run ... -- -p`. Attaching an agent
# with `sbx run` needs a TTY; without one it fails with
# `ERROR: inspect exec: context deadline exceeded`. Creating the sandbox and
# then driving the agent with `sbx exec` works headlessly (CI, cron, pipes).
set -euo pipefail

KIT_REF="${KIT_REF:-./}"
SERVER_NAME="${SERVER_NAME:-merge}"
SANDBOX="${SANDBOX:-merge-kit-smoke}"

if ! sbx mcp ls | awk '{print $1}' | grep -qx "$SERVER_NAME"; then
  echo "MCP server '$SERVER_NAME' is not registered. Run:" >&2
  echo "  sbx mcp add $SERVER_NAME --url https://ah-api.merge.dev/mcp" >&2
  exit 1
fi

# The agent needs its own model-provider credential or it exits immediately.
if ! sbx secret ls | grep -q anthropic; then
  echo "No 'anthropic' secret found. Claude Code cannot start without one:" >&2
  echo "  sbx secret set anthropic" >&2
  exit 1
fi

# --static-mcp is fixed at creation, so reuse an existing sandbox rather than
# trying to re-specify it.
if ! sbx ls | awk '{print $1}' | grep -qx "$SANDBOX"; then
  sbx create claude --name "$SANDBOX" --kit "$KIT_REF" --static-mcp "$SERVER_NAME"
fi

sbx exec "$SANDBOX" -- claude -p "Report how many tools the \"$SERVER_NAME\" MCP
server exposes, then call one read-only tool (prefer a *__validate_credential)
and report the result. Read-only only: no creates, updates, deletes, or posts."
