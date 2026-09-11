<!--
DRAFT — not published. Paste into the Docker Hub repository overview for
docker.io/mergeapi/merge-agent-handler when the artifact is pushed.
Written to stand alone: assume the reader has not seen the GitHub README.
-->

# Merge Agent Handler kit

A [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) **mixin kit** that
gives a sandboxed AI agent access to **Merge Agent Handler** — one
authenticated gateway to hundreds of enterprise SaaS systems (CRM, HRIS, ATS,
ticketing, accounting, file storage), exposed to the agent as a single MCP tool
catalog.

No Merge API key ever enters the sandbox. Authentication happens once on your
host via OAuth, and the token stays in your host keychain.

## Install

Agent Handler reaches the agent over MCP, and MCP servers are registered on the
host rather than by the kit. So this is a two-step pairing.

**1. Register the MCP server (once per host):**

```bash
sbx mcp add merge --url https://ah-api.merge.dev/mcp
```

This opens a browser for OAuth consent. Agent Handler supports Dynamic Client
Registration, so no `--client-id` is needed.

**2. Run a sandbox with the kit and the server:**

```bash
sbx run claude --kit docker.io/mergeapi/merge-agent-handler:1.0.0 --static-mcp merge
```

Pin the version tag. Kit signatures cover `spec.yaml` and `files/`, but not
which artifact a mutable tag resolves to — `:latest` exists for throwaway local
experiments, at the cost of that guarantee.

Use an agent that configures MCP at startup: Claude Code, Codex, Devin, Gemini,
Kiro, or OpenCode.

## What it does

- **Network:** allows `ah-api.merge.dev:443` and nothing else. It does not open
  egress to the SaaS systems behind Agent Handler — those calls are brokered
  server-side.
- **Credentials:** declares none. The `/mcp` endpoint is OAuth-protected, and
  `sbx mcp add` keeps the token on the host.
- **Agent instructions:** tells the agent what Agent Handler is, when to reach
  for it, and not to try authenticating to third-party systems itself.

It installs no packages, runs no startup commands, and writes no files.

## Governed organizations

Under Docker AI Governance, kit-defined allow rules are inactive — an
administrator must allow `ah-api.merge.dev` in organization network policy. MCP
server registration and tool calls are separately governed by Cedar-based MCP
access policies and may need admin approval.

## Source and issues

[github.com/merge-api/docker-merge-kit](https://github.com/merge-api/docker-merge-kit)

Licensed under Apache 2.0.
