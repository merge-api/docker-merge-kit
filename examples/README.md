# Examples

Runnable examples for the Merge Agent Handler kit. Each assumes `sbx` is
installed and you have run `sbx login`.

| Example | What it shows |
| --- | --- |
| [`quickstart.sh`](quickstart.sh) | Register the MCP server and launch a sandbox with the kit |
| [`claude-code.sh`](claude-code.sh) | Non-interactive Claude Code run that exercises the tool catalog |

Both scripts register the MCP server with `sbx mcp add`, which opens a browser
for OAuth consent on first run. Subsequent runs reuse the stored token.
