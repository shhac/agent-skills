# agent-skills

Centralised distribution point for the skills that ship with the `shhac` CLI
family — the `agent-*` tools plus `lin` and `git-hunk`. Subscribe to this one
repo and every skill updates from a single source, instead of watching N tool
repos.

> **This repo is generated.** Skills are synced here by CI from each tool's
> repo on release — the source of truth lives next to each CLI's code. Don't
> open PRs against skill content here; change it in the tool's repo instead.
> See [docs/publishing.md](docs/publishing.md) for how syncing works.

## Install skills

### Option A — skills CLI (recommended)

Install every family skill and pick interactively:

```bash
npx skills add shhac/agent-skills --global
```

Or install just the ones you want:

```bash
npx skills add shhac/agent-skills --skill agent-notion agent-sql --global
```

Update them all later — one source, one check, however many you have:

```bash
npx skills update
```

`--global` installs at the user level; drop it to install into the current
project only. Skills live under `skills/<name>/`.

### Option B — Claude Code plugin marketplace

The repo doubles as a single bundle plugin containing all the skills:

```
/plugin marketplace add shhac/agent-skills
/plugin install agent-skills@agent-skills
```

Or pre-configure in `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": [
    { "name": "agent-skills", "github": { "repo": "shhac/agent-skills" } }
  ],
  "enabledPlugins": {
    "agent-skills@agent-skills": true
  }
}
```

The bundle is all-or-nothing (it installs every skill here, `git-hunk`
included). For per-skill selection, use Option A.

## You still need the binaries

Skills document CLIs — the binaries come from the Homebrew tap:

```bash
brew install shhac/tap/<tool>     # e.g. brew install shhac/tap/agent-notion
```

Each skill's `manifest.json` entry records exactly which tool version it
documents (`repo`, `tag`, `commit`, `synced_at`). If a skill seems to
disagree with your installed CLI, compare against `<tool> --version` and
`brew upgrade`.

## Available skills

17 skills, synced from their source repos. See
[manifest.json](manifest.json) for the authoritative list with exact
versions and provenance.

<!-- Keep this table in step with skills/ and manifest.json when a skill is
     added or removed (versions live in manifest.json, not here). -->

| Skill | What it does | Source |
|---|---|---|
| agent-cloudflare | Cloudflare zones, DNS, WAF/rulesets, cache, Workers, KV, R2, audit logs | [shhac/agent-cloudflare](https://github.com/shhac/agent-cloudflare) |
| agent-code-review | PR review queue + scheduler — review cycles, serve daemon + dashboard | [shhac/agent-code-review](https://github.com/shhac/agent-code-review) |
| agent-dd | Datadog monitors, logs, metrics, traces, incidents, SLOs | [shhac/agent-dd](https://github.com/shhac/agent-dd) |
| agent-deepweb | Credential-gated HTTP for agents — named profiles, secrets never exposed | [shhac/agent-deepweb](https://github.com/shhac/agent-deepweb) |
| agent-incident | incident.io incidents, alerts, on-call schedules, escalations, status pages | [shhac/agent-incident](https://github.com/shhac/agent-incident) |
| agent-mcp-host | One-origin MCP host for the family — single OAuth AS + reverse proxy | [shhac/agent-mcp-host](https://github.com/shhac/agent-mcp-host) |
| agent-mongo | Read-only MongoDB CLI — explore, query, aggregate | [shhac/agent-mongo](https://github.com/shhac/agent-mongo) |
| agent-notion | Notion CLI for humans and LLMs — search, read, CRUD, export, AI chat | [shhac/agent-notion](https://github.com/shhac/agent-notion) |
| agent-posthog | PostHog analytics, HogQL, feature flags, insights, session replays | [shhac/agent-posthog](https://github.com/shhac/agent-posthog) |
| agent-postmark | Postmark delivery, bounces, suppressions, DKIM/SPF, message streams | [shhac/agent-postmark](https://github.com/shhac/agent-postmark) |
| agent-slack | Slack CLI for agents — read, search, send, react, schedule | [shhac/agent-slack](https://github.com/shhac/agent-slack) |
| agent-sql | Read-only-by-default SQL CLI — 8 databases (Postgres, MySQL, SQLite, …) | [shhac/agent-sql](https://github.com/shhac/agent-sql) |
| agent-statsig | Statsig feature gates, dynamic configs, experiments, segments | [shhac/agent-statsig](https://github.com/shhac/agent-statsig) |
| agent-stripe | Stripe payments, invoices, subscriptions, disputes, refunds, Connect | [shhac/agent-stripe](https://github.com/shhac/agent-stripe) |
| agent-vercel | Vercel deployments, build/runtime logs, env vars, domains, WAF | [shhac/agent-vercel](https://github.com/shhac/agent-vercel) |
| git-hunk | Non-interactive hunk staging for git — a scriptable `git add` | [shhac/git-hunk](https://github.com/shhac/git-hunk) |
| lin | Linear CLI for humans and LLMs — issues, projects, cycles, comments | [shhac/lin](https://github.com/shhac/lin) |

`git-hunk` is a general-purpose git tool that happens to live here too. If
it's all you want, install it on its own — `npx skills add shhac/git-hunk` —
no need for the rest of the family.

## Publishing (maintainers)

Each tool repo calls the reusable
[`sync-skill.yml`](.github/workflows/sync-skill.yml) workflow on `v*` (CLI
release) and `skill-v*` (skill-only release) tags. Setup and conventions:
[docs/publishing.md](docs/publishing.md).
