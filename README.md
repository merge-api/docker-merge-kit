# Merge Agent Handler kit

A [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) **mixin kit** that
gives a sandboxed AI agent access to
[Merge Agent Handler](https://docs.merge.dev/merge-agent-handler/overview) —
a single authenticated gateway to hundreds of enterprise SaaS systems (CRM,
HRIS, ATS, ticketing, accounting, file storage) exposed as one MCP tool
catalog.

The kit tells the agent what Agent Handler is and when to use it, pins the
sandbox's egress policy, and leaves every credential outside the sandbox VM.

> **Status:** v1. Docker's kit format is experimental and still changing; this
> kit targets `schemaVersion: "2"` and is validated against `sbx` v0.42.1.

## What's in the kit

| Kit declares | Value |
| --- | --- |
| `kind` | `mixin` — layers onto any agent sandbox |
| `permissions.network.allow` | `ah-api.merge.dev:443` — nothing else. Defense in depth; see [Network access](#network-access-this-kit-opens) |
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

**Give your agent its own model-provider credential.** This is separate from
anything the kit does, and it is the most common first-run failure: without it
the agent exits immediately with `ERROR: agent exited with code 1` and no
explanation. For Claude Code:

```bash
sbx secret set anthropic
```

Use the service matching your agent — `sbx secret set` supports `anthropic`,
`openai`, `google`, `copilot`, `cursor`, `devin`, `droid`, and others. Claude
Code can also sign in with OAuth instead of an API key.

To be clear about which credential does what:

| Credential | Purpose | Supplied by |
| --- | --- | --- |
| Model provider (e.g. Anthropic) | Lets the agent run at all | `sbx secret set <service>` |
| Merge Agent Handler OAuth | Authorizes the tool calls | `sbx mcp add merge` (step 1 below) |

Neither one enters the sandbox: the provider credential is proxy-managed by the
built-in agent kit, and the Merge token stays in your host keychain.

**Use an agent with MCP-at-startup support.** The kit itself is a plain mixin
and will layer onto any agent sandbox, but the MCP pairing below only works
with agents that configure MCP at startup. Docker currently lists:

- Claude Code
- Codex
- Devin
- Gemini
- Kiro
- OpenCode

With any other agent the kit still applies, but the `merge` server will not be
wired up and the tool catalog will not appear.

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

Pin an explicit version tag:

```bash
sbx run claude --kit docker.io/mergeapi/merge-agent-handler:1.0.1 --static-mcp merge
```

Kit signatures cover `spec.yaml` and `files/`, but not which artifact a mutable
tag happens to point at. Pinning a version is what makes the signature mean
something, so prefer it anywhere reproducibility matters — CI, shared developer
setups, anything governed.

`docker.io/mergeapi/merge-agent-handler:latest` also exists as a convenience for
throwaway local experiments, at the cost of that guarantee.

To run against a local checkout of this repo:

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
two reasons:

1. **The endpoint is OAuth-only.** `/mcp` rejects API keys outright. An
   `apiKey` block pointed at it would never authenticate.
2. **The gateway already provides the isolation.** `sbx mcp add` performs
   host-side OAuth and keeps the token in the host credential store. The
   sandbox never holds it — which is exactly the property a proxy-managed
   credential would have been buying.

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

**This rule is defense in depth, not the thing that makes the kit work.** It is
worth being precise about, because the obvious reading is wrong.

Per Docker's documented architecture, the agent inside the sandbox connects
only to the sandbox's MCP gateway, and the gateway is what talks to a remote
MCP server. Docker draws the line explicitly: MCP access policies govern
"requests handled by Docker's MCP gateway," whereas "a direct connection to a
remote MCP server is outbound sandbox traffic, so network access policy
determines whether the sandbox can reach the server." Gateway-routed traffic is
governed as MCP activity; network policy is what governs traffic that leaves
the sandbox directly.

So on the `--static-mcp merge` path described above, this allow rule is never
exercised — the MCP calls are not sandbox egress. It is kept anyway because:

- **It is a hook for the direct-API path.** Anything that calls Agent Handler
  straight from inside the VM — a `curl` against the REST API, a script, a
  future non-gateway integration — *is* sandbox egress, and needs this rule.
- **It documents intent.** The kit states the one host it is entitled to reach,
  which is what a reviewer and an org admin both want to see.
- **It costs nothing.** Under a default-deny posture the rule grants exactly
  one host and port.

What the rule does **not** do is grant egress to the SaaS systems behind Agent
Handler. Agent Handler brokers those calls server-side and holds those
credentials itself, so the sandbox needs no route to Salesforce, Slack,
Workday, or anything else.

> **Verified empirically.** Running the pairing on `sbx` v0.42.1 with a live
> Merge account — 717 tools listed and a successful `salesforce__validate_credential`
> call — produced this `sbx policy log`:
>
> ```
> SANDBOX             TYPE      HOST                             RULE
> claude-docker-kit   network   api.anthropic.com:443
> claude-docker-kit   network   mcp-gateway.docker.internal:80   <daemon-managed alias>
> claude-docker-kit   network   ports.ubuntu.com:80
> claude-docker-kit   network   download.docker.com:443
> ```
>
> `ah-api.merge.dev` does not appear. The sandbox's MCP traffic terminates at
> `mcp-gateway.docker.internal`; the gateway makes the outbound call host-side.
> The global policy did not allow `ah-api.merge.dev` either, so had the traffic
> crossed the boundary it would have needed this kit's rule and would have been
> logged.

## Enterprise / governed orgs

Two things change once Docker AI Governance is active for your organization,
and both will bite a deployer who assumes the kit is self-sufficient.

### Kit-defined allow rules stop granting access

Under organization governance, only **organization** allow rules grant network
access. Local and kit-defined allow rules become inactive and cannot expand
what the org permits. Deny rules still apply from every source:

| Rule | Evaluated under organization governance |
| --- | --- |
| Organization allow | Yes |
| Organization deny | Yes |
| Local allow | No |
| Local deny | Yes |
| Kit-defined allow | **No** |
| Kit-defined deny | Yes |

So in a governed org, **an administrator must allow `ah-api.merge.dev`
centrally.** This kit's allow rule will not do it. Concretely, the org network
policy needs a `connect:tcp` rule for `ah-api.merge.dev` (or
`ah-api.merge.dev:443`).

This is also why the rule above is defense in depth rather than load-bearing:
in exactly the environments that matter most, it is inactive by design.

### MCP registration and tool calls are separately governed

Network policy is not the only gate. MCP access policies are organization
policies written in Cedar, and they apply at two distinct points:

- **Registration** — when a developer runs `sbx mcp add merge --url ...`,
  matched on the registered name and resolved server attributes.
- **Use** — when the gateway handles a tool call, resource read, or prompt
  retrieval from an already-registered server.

A rule at one point does not govern the other, and MCP activity is default-deny
under governance. So the `merge` registration may need admin approval, and tool
calls may *separately* need to be permitted or may require interactive
confirmation. If registration succeeds but tools fail at call time, look at
use-time MCP policy before suspecting the kit.

See Docker's
[MCP access policies](https://docs.docker.com/ai/sandboxes/governance/access-controls/mcp/)
and
[network access policies](https://docs.docker.com/ai/sandboxes/governance/access-controls/network/).

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

CI runs `sbx kit validate` on every pull request, plus a negative control that
asserts a deliberately broken spec is rejected — see
[.github/workflows/validate.yml](.github/workflows/validate.yml).

Publishing to Docker Hub (`sbx kit push`) and signing are handled separately
and deliberately kept out of CI.

## License

[Apache 2.0](LICENSE)
