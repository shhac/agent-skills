#!/usr/bin/env bash
# Sync one skill from a source-repo checkout into this repo. Regenerates:
# plugins/<name>/, manifest.json, and .claude-plugin/marketplace.json. Run
# from anywhere; operates on the repo this script lives in.
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

# One tree serves both consumers: the skills CLI (npx skills add) discovers
# the nested SKILL.md, and the Claude Code marketplace installs the plugin.
mkdir -p "plugins/$SKILL_NAME/skills/$SKILL_NAME" "plugins/$SKILL_NAME/.claude-plugin"
rsync -a --delete "$SRC_DIR/" "plugins/$SKILL_NAME/skills/$SKILL_NAME/"

# First line of the SKILL.md frontmatter description (inline or block style).
description="$(awk '
  /^description:[[:space:]]*[|>]/ { block = 1; next }
  block && /^[^[:space:]]/ { exit }
  block { sub(/^[[:space:]]+/, ""); if ($0 != "") { print; exit } }
  /^description:[[:space:]]*[^|>[:space:]]/ { sub(/^description:[[:space:]]*/, ""); print; exit }
' "plugins/$SKILL_NAME/skills/$SKILL_NAME/SKILL.md")"
if [ "${#description}" -gt 300 ]; then
  description="$(printf '%s' "${description:0:300}" | sed 's/ [^ ]*$//')…"
fi
[ -n "$description" ] || description="Claude Code skill for the $SKILL_NAME CLI"

jq -n \
  --arg name "$SKILL_NAME" \
  --arg version "$version" \
  --arg description "$description" \
  --arg repo "$SRC_REPO" \
  '{
    name: $name,
    version: $version,
    description: $description,
    author: { name: "Paul Somers", url: "https://github.com/shhac" },
    repository: ("https://github.com/" + $repo)
  }' > "plugins/$SKILL_NAME/.claude-plugin/plugin.json"

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

# The marketplace is derived entirely from the plugin manifests, so
# name/version can never drift between the two.
mkdir -p .claude-plugin
jq -s '{
  name: "agent-skills",
  description: "Skills for the shhac agent-* CLI family, synced from each tool'\''s repo on release",
  version: "1.0.0",
  owner: { name: "Paul Somers", url: "https://github.com/shhac" },
  pluginRoot: "./plugins",
  plugins: [ .[] | {
    name,
    source: ("./plugins/" + .name),
    version,
    description,
    author,
    repository
  } ]
}' plugins/*/.claude-plugin/plugin.json > .claude-plugin/marketplace.json

echo "synced $SKILL_NAME $version from $SRC_REPO@$SRC_TAG (${SRC_COMMIT:0:7})"
