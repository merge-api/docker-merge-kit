# Examples

Runnable examples for the Merge Agent Handler kit. Each assumes `sbx` is
installed and you have run `sbx login`.

| Example | What it shows |
| --- | --- |
| [`quickstart.sh`](quickstart.sh) | Register the MCP server and launch a sandbox with the kit |
| [`claude-code.sh`](claude-code.sh) | Headless smoke test: creates a sandbox, then drives the agent with `sbx exec` |
| [`customer-issue-triage.sh`](customer-issue-triage.sh) | Developer workflow: correlate local code with read-only CRM and support context |

All three examples need the MCP server registered with `sbx mcp add`, which opens a
browser for OAuth consent on first run; subsequent runs reuse the stored token.
They also need the agent's own model-provider credential (`sbx secret set
anthropic` for Claude Code) — without it the agent exits immediately.

## Customer issue triage demo

Run the workflow against an application repository and a test account that
exists in one of your connected systems:

```bash
./examples/customer-issue-triage.sh \
  "Acme Test Account" \
  "Webhook deliveries started returning 401 after key rotation" \
  /path/to/application
```

The agent inspects the application code, looks up the account and related
support context through granted Agent Handler tools, and returns an incident
brief that separates evidence from hypotheses. The prompt prohibits writes,
access requests, and connector authentication, so it is suitable for a shared
demo environment.

The script reuses its sandbox. If you point it at another application, set a
new name with `SANDBOX=<name>` so Docker mounts the intended workspace.

`claude-code.sh` uses `sbx create` + `sbx exec` rather than `sbx run ... -- -p`,
because attaching with `sbx run` requires a TTY and fails headlessly with
`ERROR: inspect exec: context deadline exceeded`.
