# Examples

Runnable examples for the Merge Agent Handler kit. Each assumes `sbx` is
installed and you have run `sbx login`.

| Example | What it shows |
| --- | --- |
| [`quickstart.sh`](quickstart.sh) | Register the MCP server and launch a sandbox with the kit |
| [`claude-code.sh`](claude-code.sh) | Headless smoke test: creates a sandbox, then drives the agent with `sbx exec` |

Both scripts need the MCP server registered with `sbx mcp add`, which opens a
browser for OAuth consent on first run; subsequent runs reuse the stored token.
They also need the agent's own model-provider credential (`sbx secret set
anthropic` for Claude Code) — without it the agent exits immediately.

`claude-code.sh` uses `sbx create` + `sbx exec` rather than `sbx run ... -- -p`,
because attaching with `sbx run` requires a TTY and fails headlessly with
`ERROR: inspect exec: context deadline exceeded`.
