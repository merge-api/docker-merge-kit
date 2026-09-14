#!/usr/bin/env bash
# Demo a developer investigating a customer-reported issue by combining local
# code with read-only CRM and support data from Merge Agent Handler.
#
# Usage:
#   ./examples/customer-issue-triage.sh "ACCOUNT NAME" "ISSUE SUMMARY" [WORKSPACE]
#
# Run this against the application repository being investigated, not this kit
# repository. Set SERVER_NAME, SANDBOX, or KIT_REF to override their defaults.
set -euo pipefail

ACCOUNT_NAME="${1:-}"
ISSUE_SUMMARY="${2:-}"
WORKSPACE="${3:-.}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
KIT_REF="${KIT_REF:-$SCRIPT_DIR/..}"
SERVER_NAME="${SERVER_NAME:-merge}"
SANDBOX="${SANDBOX:-merge-customer-triage}"

if [[ -z "$ACCOUNT_NAME" || -z "$ISSUE_SUMMARY" ]]; then
  echo "Usage: $0 \"ACCOUNT NAME\" \"ISSUE SUMMARY\" [WORKSPACE]" >&2
  exit 2
fi

if [[ ! -d "$WORKSPACE" ]]; then
  echo "Workspace does not exist or is not a directory: $WORKSPACE" >&2
  exit 2
fi

MCP_LIST="$(sbx mcp ls)"
if ! printf '%s\n' "$MCP_LIST" | awk '{print $1}' | grep -qx "$SERVER_NAME" \
  && [[ "$SERVER_NAME" == "merge" ]] \
  && printf '%s\n' "$MCP_LIST" | awk '{print $1}' | grep -qx "merge-agent-handler"; then
  SERVER_NAME="merge-agent-handler"
fi

if ! printf '%s\n' "$MCP_LIST" | awk '{print $1}' | grep -qx "$SERVER_NAME"; then
  echo "MCP server '$SERVER_NAME' is not registered. Run:" >&2
  echo "  sbx mcp add $SERVER_NAME --url https://ah-api.merge.dev/mcp" >&2
  exit 1
fi

if printf '%s\n' "$MCP_LIST" | awk -v name="$SERVER_NAME" \
  '$1 == name && /needs auth/ {found=1} END {exit !found}'; then
  echo "MCP server '$SERVER_NAME' needs authentication. Run:" >&2
  echo "  sbx mcp auth $SERVER_NAME" >&2
  exit 1
fi

if ! sbx secret ls | grep -q anthropic; then
  echo "No 'anthropic' secret found. Claude Code cannot start without one:" >&2
  echo "  sbx secret set anthropic" >&2
  exit 1
fi

if sbx ls | awk '{print $1}' | grep -qx "$SANDBOX"; then
  EXISTING_AGENT="$(sbx ls | awk -v name="$SANDBOX" '$1 == name {print $2}')"
  if [[ "$EXISTING_AGENT" != "claude" ]]; then
    echo "Sandbox '$SANDBOX' uses agent '$EXISTING_AGENT', not 'claude'." >&2
    echo "Choose another name with SANDBOX=<name> and run again." >&2
    exit 1
  fi
else
  sbx create claude --name "$SANDBOX" --kit "$KIT_REF" \
    --static-mcp "$SERVER_NAME" "$WORKSPACE"
fi

read -r -d '' PROMPT <<EOF || true
You are the developer on call, investigating a customer-reported issue.

Customer account: $ACCOUNT_NAME
Reported issue: $ISSUE_SUMMARY

Conduct a read-only investigation that combines evidence from this repository
with relevant customer and support context available through Merge Agent
Handler.

1. Inspect the repository first. Identify the code, configuration, or recent
   changes most likely involved. Cite file paths and line numbers.
2. Use search_tools before calling business-system tools. Find granted,
   read-only tools that can locate the customer account and relevant recent
   support tickets, cases, or conversations. Use whichever connected CRM and
   support systems are available. Never guess tool names.
3. Retrieve only the records needed for this issue. Do not create, update,
   delete, post, request more access, or attempt to authenticate a connector.
4. Correlate the external evidence with the code. Separate observed facts from
   hypotheses.

Return a compact incident brief with these sections:

- Summary
- Customer context, including the source system and record
- Code findings, including paths and lines
- Most likely failure path
- Next debugging step
- Missing access or data

Do not treat credential validation or a tool count as the result. Complete at
least one repository finding and one business-system lookup. If either is
blocked, name the exact blocker and still report the evidence you could gather.
EOF

sbx exec "$SANDBOX" -- claude -p "$PROMPT"
