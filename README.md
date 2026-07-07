# agent-skills

Centralised distribution point for the skills that ship with the `shhac`
`agent-*` CLI family (agent-notion, agent-slack, agent-mongo, agent-sql, lin,
…). Subscribe to this one repo instead of N tool repos.

> **This repo is generated.** Skills are synced here by CI from each tool's
> repo on release — the source of truth lives next to each CLI's code. Don't
> open PRs against skill content here; change it in the tool's repo instead.
> See [docs/publishing.md](docs/publishing.md) for how syncing works.

## Install skills

### Option A — skills CLI

```bash
npx skills add shhac/agent-skills
```

Then pick the skills for the tools you use. Skills live under `skills/<name>/`.

### Option B — Claude Code plugin marketplace

```
/plugin marketplace add shhac/agent-skills
/plugin install agent-notion@agent-skills
```

Or pre-configure in `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": [
    { "name": "agent-skills", "github": { "repo": "shhac/agent-skills" } }
  ],
  "enabledPlugins": {
    "agent-notion@agent-skills": true
  }
}
```

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

See [manifest.json](manifest.json) for the authoritative list with versions
and provenance.

| Skill | Tool | Source |
|---|---|---|
| agent-notion | Notion CLI for humans and LLMs | [shhac/agent-notion](https://github.com/shhac/agent-notion) |

## Publishing (maintainers)

Each tool repo calls the reusable
[`sync-skill.yml`](.github/workflows/sync-skill.yml) workflow on `v*` (CLI
release) and `skill-v*` (skill-only release) tags. Setup and conventions:
[docs/publishing.md](docs/publishing.md).
