# Merge Agent Handler kit

A [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) **mixin kit** that
gives a sandboxed AI agent access to
[Merge Agent Handler](https://docs.merge.dev/merge-agent-handler/overview) —
a single authenticated gateway to hundreds of enterprise SaaS systems (CRM,
HRIS, ATS, ticketing, accounting, file storage) exposed as one MCP tool
catalog.

The kit opens exactly one host on the sandbox network, tells the agent what
Agent Handler is and when to use it, and leaves every credential outside the
sandbox VM.

> **Status:** v1. Docker's kit format is experimental and still changing; this
> kit targets `schemaVersion: "2"` and is validated against `sbx` v0.42.1.

## What's in the kit

| Kit declares | Value |
| --- | --- |
| `kind` | `mixin` — layers onto any agent sandbox (`claude`, `codex`, `gemini`, …) |
| `permissions.network.allow` | `ah-api.merge.dev:443` — nothing else |
| `agentInstructions` | What Agent Handler is, when to reach for it, and not to authenticate to third-party systems directly |
| `credentials` | **none** — see [Why there is no credential block](#why-there-is-no-credential-block) |

The kit installs no packages, runs no startup commands, and writes no files.
It touches none of Docker's
[reserved agent-managed config paths](https://docs.docker.com/ai/sandboxes/customize/kits/)
(`~/.claude.json`, `~/.codex/config.toml`, and friends) — there is nothing for
it to configure there, because MCP registration happens on the host.

## Prerequisites

Install the `sbx` CLI:

```bash
brew trust docker/tap && brew install docker/tap/sbx
```

Then sign in, which the MCP gateway requires:

```bash
sbx login
```

## Usage

Agent Handler reaches the sandbox over MCP, and **MCP servers are registered on
the host, not by the kit**. So this is a two-step pairing: register the server
once, then run the sandbox with both the kit and the server.

### 1. Register the Agent Handler MCP server (once per host)

```bash
sbx mcp add merge --url https://ah-api.merge.dev/mcp
```

`sbx` discovers Agent Handler's OAuth metadata (RFC 9728/8414) and opens a
browser authorization flow. Agent Handler supports Dynamic Client
Registration, so you do **not** need to pre-register an OAuth client or pass
`--client-id`. Approve the request and the registration is stored:

```bash
$ sbx mcp ls
NAME     TYPE     URL/COMMAND
merge    remote   https://ah-api.merge.dev/mcp
```

The resulting OAuth token is kept in your host OS credential store (macOS
Keychain, Windows Credential Manager, Linux Secret Service).

### 2. Run a sandbox with the kit and the server

```bash
sbx run claude --kit docker.io/merge/merge-agent-handler-kit:latest --static-mcp merge
```

Or against a local checkout of this repo:

```bash
sbx run claude --kit ./ --static-mcp merge
```

`--static-mcp` pre-loads the `merge` server at creation. Omit it to use dynamic
mode, where the agent discovers and attaches registered servers itself.

## How you supply your Merge credential

**You do not paste a Merge API key into the sandbox, and the kit never asks for
one.** Authentication happens once on the host, in step 1 above, through OAuth.

`https://ah-api.merge.dev/mcp` is OAuth-protected and rejects raw API keys:

```
$ curl -X POST https://ah-api.merge.dev/mcp -H 'Authorization: Bearer <api-key>'
401  {"detail":"OAuth authentication required."}
```

So the flow is:

1. `sbx mcp add merge --url https://ah-api.merge.dev/mcp` → browser consent.
2. `sbx` stores the access and refresh tokens in your **host** keychain.
3. The sandbox's MCP gateway presents that token on outbound calls.
4. The agent inside the VM never sees it, and cannot read it.

To re-authorize or revoke, re-run `sbx mcp add`, or `sbx mcp rm merge`.

> Agent Handler also exposes an API-key surface at a different, path-scoped URL
> (`/api/v1/tool-packs/<TOOL_PACK_ID>/registered-users/<REGISTERED_USER_ID>/mcp`,
> authenticated with `Authorization: Bearer <MERGE_API_KEY>`). This kit
> deliberately does not use it — see below.

## Why there is no credential block

A kit can declare a proxy-managed credential so the agent sees only a sentinel
while the host proxy injects the real secret. That is the right tool when a
service authenticates with a static API key. It is the wrong tool here, for
three reasons:

1. **The endpoint is OAuth-only.** `/mcp` rejects API keys outright. An
   `apiKey` block pointed at it would never authenticate.
2. **The gateway already provides the isolation.** `sbx mcp add` performs
   host-side OAuth and keeps the token in the host credential store. The
   sandbox never holds it — which is exactly the property a proxy-managed
   credential would have been buying.
3. **Declaring one would break MCP.** Credential injection is keyed on
   *domain*, not path or scheme. An `apiKey` injecting `Authorization` on
   `ah-api.merge.dev` would overwrite the gateway's OAuth header on the same
   host. The proxy does not disambiguate two auth schemes on one domain — the
   contrib [`gitlab` kit](https://github.com/docker/sbx-kits-contrib/tree/main/gitlab)
   documents this same failure mode.

If you specifically need the API-key/tool-pack surface, that is a different
kit shape and worth filing as a separate issue.

## Network access this kit opens

One host, one port:

```yaml
permissions:
  network:
    allow:
      - ah-api.merge.dev:443
```

That single host serves both the MCP endpoint (`/mcp`) and the OAuth
authorization server that protects it (`/o/authorize/`, `/o/token/`,
`/o/register/`, `/o/revoke_token/`). There are no cross-host redirects and no
separate auth or CDN origin.

Notably, the kit does **not** open egress to the SaaS systems Agent Handler
talks to. Agent Handler brokers those calls server-side and holds those
credentials itself, so the sandbox needs no route to Salesforce, Slack,
Workday, or anything else. Deny rules elsewhere in your composition still take
precedence over this allow.

## On kit-level MCP registration

The v2 kit schema has **no MCP block**, so a kit cannot register an MCP server.
Verified against `sbx` v0.42.1 (latest at time of writing) rather than assumed:

```
$ sbx kit validate ./mcptest
INVALID: artifact: invalid spec.yaml: yaml: unmarshal errors:
  line 4: field mcp not found in type spec.specFileV2
```

This is why registration is a documented manual step rather than something the
kit does. If a future `sbx` release adds kit-level MCP support, this kit should
fold step 1 into `spec.yaml` and the two-step pairing above can go away.

## Development

Validate the spec:

```bash
sbx kit validate ./
```

Inspect what the loader actually parsed:

```bash
sbx kit inspect ./ --json
```

CI runs `sbx kit validate` on every pull request — see
[.github/workflows/validate.yml](.github/workflows/validate.yml).

Publishing to Docker Hub (`sbx kit push`) and signing are handled separately
and deliberately kept out of CI.

## License

[Apache 2.0](LICENSE)
