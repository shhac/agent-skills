# Publishing a skill to agent-skills

Each `agent-*` CLI repo owns its skill (source of truth stays next to the
code, updated in the same commit as the commands it documents). This repo is
a **generated distribution mirror** — skills are pushed here by a reusable
GitHub workflow, never edited in place.

## One-time setup per source repo

1. Generate a deploy key pair (no passphrase):

   ```bash
   ssh-keygen -t ed25519 -N "" -C "agent-skills deploy key (<tool>)" -f /tmp/agent-skills-deploy
   ```

2. Add the **public** key to this repo with write access:

   ```bash
   gh repo deploy-key add /tmp/agent-skills-deploy.pub -R shhac/agent-skills \
     --allow-write --title "<tool> skill sync"
   ```

3. Add the **private** key as a secret in the source repo:

   ```bash
   gh secret set SKILLS_DEPLOY_KEY -R shhac/<tool> < /tmp/agent-skills-deploy
   rm /tmp/agent-skills-deploy /tmp/agent-skills-deploy.pub
   ```

4. Add the publish workflow to the source repo
   (`.github/workflows/publish-skill.yml`):

   ```yaml
   name: Publish skill

   on:
     push:
       tags: ['v*', 'skill-v*']

   jobs:
     publish-skill:
       uses: shhac/agent-skills/.github/workflows/sync-skill.yml@main
       with:
         skill_name: <tool>
       secrets:
         SKILLS_DEPLOY_KEY: ${{ secrets.SKILLS_DEPLOY_KEY }}
   ```

   `skill_path` defaults to `skills/<skill_name>` in the source repo; pass it
   explicitly if the skill lives elsewhere.

## Tagging conventions

- **`vX.Y.Z`** — a normal CLI release. The skill is synced automatically as
  part of the release, so the distributed skill always snapshots the behavior
  of the released binary.
- **`skill-vX.Y.Z`** — a skill-only release (better triggers, examples,
  wording) between CLI releases. **Convention:** the tagged skill content
  must describe the *released* CLI. Because skill edits land in the same
  commit as the CLI changes they document, `main`'s skill can be ahead of the
  released binary — don't `skill-v` tag a commit that documents unreleased
  flags or output shapes.

## What the sync does

`scripts/sync-skill.sh` (run by the workflow in this repo's checkout):

1. `rsync --delete` the skill folder into `skills/<name>/` — the only
   content tree. The skills CLI discovers it directly; the Claude Code side
   installs the repo root as a single bundle plugin (root
   `.claude-plugin/plugin.json` auto-discovers `skills/`), so nothing is
   duplicated.
2. Record provenance in `manifest.json` (repo, tag, commit, synced-at).
3. Regenerate `.claude-plugin/plugin.json` (bundle version = sync date) and
   `.claude-plugin/marketplace.json` from it, so marketplace and plugin
   versions can never disagree.
4. Regenerate the README "Available skills" table (`scripts/gen-readme.py`)
   from `manifest.json` + each `SKILL.md`, between the `skills-table`
   markers — so the published list never drifts from what the repo ships.
   Don't hand-edit that table; edit the source `SKILL.md` instead.
5. Commit with provenance (`sync(<name>): <repo>@<tag> (<sha>)`) and push,
   with a rebase-retry loop to absorb races between concurrently releasing
   tools.
