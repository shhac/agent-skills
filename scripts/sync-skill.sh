#!/usr/bin/env bash
# Sync one skill from a source-repo checkout into this repo. The flat
# skills/<name>/ tree is the only content tree; the repo root doubles as a
# single Claude Code plugin (root .claude-plugin/plugin.json auto-discovers
# skills/), listed by .claude-plugin/marketplace.json as source "./".
# Regenerates: skills/<name>/, manifest.json, plugin.json, marketplace.json.
# Run from anywhere; operates on the repo this script lives in.
#
# Required env:
#   SKILL_NAME  — skill folder name (e.g. agent-notion)
#   SRC_DIR     — absolute path to the skill folder in the source checkout
#   SRC_REPO    — source repository (e.g. shhac/agent-notion)
#   SRC_TAG     — tag being published (v1.2.3 or skill-v1.2.3)
#   SRC_COMMIT  — source commit SHA
set -euo pipefail

: "${SKILL_NAME:?}" "${SRC_DIR:?}" "${SRC_REPO:?}" "${SRC_TAG:?}" "${SRC_COMMIT:?}"

cd "$(dirname "$0")/.."

if [ ! -f "$SRC_DIR/SKILL.md" ]; then
  echo "error: no SKILL.md in $SRC_DIR" >&2
  exit 1
fi

version="${SRC_TAG#skill-}"
version="${version#v}"
synced_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "skills/$SKILL_NAME"
rsync -a --delete "$SRC_DIR/" "skills/$SKILL_NAME/"

# Provenance: skill → where it came from.
[ -f manifest.json ] || echo '{}' > manifest.json
jq \
  --arg name "$SKILL_NAME" \
  --arg repo "$SRC_REPO" \
  --arg tag "$SRC_TAG" \
  --arg commit "$SRC_COMMIT" \
  --arg version "$version" \
  --arg synced_at "$synced_at" \
  '.[$name] = { repo: $repo, tag: $tag, commit: $commit, version: $version, synced_at: $synced_at }' \
  manifest.json > manifest.json.tmp && mv manifest.json.tmp manifest.json

# The Claude Code side is one bundle plugin (the repo root), versioned by
# sync date. Zero-padded date segments are invalid semver, so strip them.
bundle_version="$(date -u +%Y).$((10#$(date -u +%m))).$((10#$(date -u +%d)))"

mkdir -p .claude-plugin
jq -n \
  --arg version "$bundle_version" \
  '{
    name: "agent-skills",
    version: $version,
    description: "Skills for the shhac agent-* CLI family, synced from each tool'\''s repo on release. See manifest.json for per-skill provenance.",
    author: { name: "Paul Somers", url: "https://github.com/shhac" },
    repository: "https://github.com/shhac/agent-skills"
  }' > .claude-plugin/plugin.json

jq -n \
  --slurpfile plugin .claude-plugin/plugin.json \
  '{
    name: "agent-skills",
    description: $plugin[0].description,
    version: $plugin[0].version,
    owner: $plugin[0].author,
    plugins: [ {
      name: $plugin[0].name,
      source: "./",
      version: $plugin[0].version,
      description: $plugin[0].description,
      author: $plugin[0].author,
      repository: $plugin[0].repository
    } ]
  }' > .claude-plugin/marketplace.json

# Regenerate the README skills table from manifest.json + each SKILL.md so the
# published list can never drift from what the repo actually ships. Skipped
# (non-fatally) if python3 is unavailable in the runner.
if command -v python3 >/dev/null 2>&1; then
  python3 scripts/gen-readme.py
else
  echo "warning: python3 not found — README skills table not regenerated" >&2
fi

echo "synced $SKILL_NAME $version from $SRC_REPO@$SRC_TAG (${SRC_COMMIT:0:7})"
