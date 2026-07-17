---
name: agent-incident
description: Triage and manage incident.io incidents, alerts, schedules, escalations, and status pages. Use when the user asks about active incidents, who's on-call, alert status, escalating to responders, incident severity, follow-up actions, pager schedules, or status page updates.
allowed-tools: Bash(agent-incident *) Read Grep Glob
---

# agent-incident — incident.io Triage CLI

Query and manage incident.io incidents, alerts, schedules, escalations, and status pages. Triage and response workflows only — not full incident.io administration.

## When to Use

- Checking what incidents are active and their severity
- Finding out who's on-call right now
- Investigating which alerts are firing
- Escalating an incident to the right responders
- Editing incident fields: severity, status, custom fields, and timestamps
- Updating status pages during an incident
- Reviewing follow-up actions after resolution

## Process

### Incident response workflow

1. **What's happening?** `incident list --status active` to see active incidents
2. **How bad is it?** `incident get INC-2000` for full details including severity and timeline (also accepts multiple ids: `incident get INC-2000 INC-2001`)
3. **What triggered it?** `alert list --status firing` to see current alerts
4. **Who's on-call?** `oncall schedule entries Engineering --from now --to now+1h`
5. **Escalate if needed:** `oncall escalation create --incident <id> --path "Primary Path"`
6. **Communicate:** `status-page update create --page "Public Status" --name "..."`

### Always read before acting

- Check incident details before editing: `incident get <id>`
- Check who's already assigned before escalating: look at `incident_role_assignments` in the get response
- Check current severity levels: `ref severity list`

### Error handling

Errors are JSON to stderr with a classification:
- `fixable_by: agent` — bad ID or missing flag. Read the hint and retry.
- `fixable_by: human` — credentials or permissions. Tell the user.
- `fixable_by: retry` — rate limit or server error. Wait and retry once.

## Quick Reference

```bash
# What's happening right now?
agent-incident incident list --status active
agent-incident alert list --status firing

# Investigate a specific incident (accepts INC-2000, 2000, or UUID)
agent-incident incident get INC-2000
agent-incident incident updates <id>

# Who's on-call? (accepts schedule name or ID)
agent-incident oncall schedule list
agent-incident oncall schedule entries Engineering --from now --to now+1h

# Respond (--path accepts name or ID)
agent-incident oncall escalation create --incident <id> --path "Primary Path"
agent-incident incident edit INC-2000 --summary "Root cause identified: ..."
agent-incident incident edit INC-2000 --severity SEV2 --status Investigating
agent-incident incident edit INC-2000 --field "Affected Team=Platform" --field "Root Cause=DNS"
agent-incident incident edit INC-2000 --timestamp "Resolved at=2026-04-09T15:30:00Z"

# Create an incident (use ref severity list to find valid IDs)
agent-incident ref severity list
agent-incident incident create --name "API latency spike" --severity <severity-id>

# Override on-call coverage (accepts names for schedule and user)
agent-incident oncall schedule override Engineering --user alice@example.com --from now --to now+4h

# After resolution
agent-incident follow-up list --incident <id>
agent-incident action list --incident <id>

# Communicate externally (--page accepts name or ID)
agent-incident status-page list
agent-incident status-page update create --page "Public Status" --name "Degraded API performance"
agent-incident status-page update update <sp-inc-id> --status resolved
```

## Key Concepts

- **Time formats**: relative (`now-15m`, `now-1h`, `now+1h`), RFC3339, or unix epoch
- **Output**: NDJSON for lists and gets (one line per id). `--full` for complete API response. `--format json|yaml|jsonl` to override. `--format json` on a get returns `{"data":[...],"@unresolved":[...]}` envelope
- **Compact mode**: List commands omit large fields (description, custom fields, timestamps) by default. Use `--full` to include everything
- **Name resolution**: Schedule, escalation path, status page, user, severity, status, custom field, timestamp, and catalog entry arguments accept names (case-insensitive, substring match). If the value looks like a ULID it's used as-is; otherwise a list lookup resolves the name to an ID. Ambiguous matches error with options listed.
- **Pagination**: `--limit N` controls page size, `--after <cursor>` for next page. Cursor is returned in `@pagination` NDJSON line

## Deeper Reference

Per-command details (only load when the quick reference above isn't enough):

```bash
agent-incident usage                           # full command overview
agent-incident incident usage                  # incident lifecycle, create/edit fields
agent-incident alert usage                     # alert statuses, create alert events
agent-incident oncall schedule usage           # schedule entries, overrides
agent-incident oncall escalation usage         # escalation paths, create escalations
agent-incident status-page usage               # status page update management
```

## Discovery Commands

```bash
# Reference data (what values are valid?)
agent-incident ref severity list              # valid severity levels
agent-incident ref status list                # valid incident statuses
agent-incident ref role list                  # incident roles (lead, comms, etc.)
agent-incident ref custom-field list          # org-specific custom fields
agent-incident ref timestamp list             # timestamp definitions (Reported at, Resolved at, etc.)

# Service catalog
agent-incident ref catalog types list
agent-incident ref catalog entries list --type <type-id> --query "checkout"

# People
agent-incident ref user list --query "alice"
agent-incident oncall escalation path list
```

## Auth Setup

If credentials aren't configured yet, set up an org **without ever putting the key on the command line**.

**Preferred (interactive) — `--form`:** pops a native OS dialog so the key is typed directly into the OS, never seen by the agent (nor placed on argv, in shell history, or in the agent transcript):
```bash
agent-incident auth add prod --form
agent-incident auth check
```

**Non-interactive — pipe the key on stdin:** for CI, scripts, or headless hosts where no dialog can appear. The key is read from stdin, so it stays off argv:
```bash
printf '%s' "$KEY" | agent-incident auth add prod
```

If a user pastes an API key into chat, **do not** put it in `--api-key <key>` — that value lands on argv, in shell history, and in this transcript. Have the user run `--form` in their own terminal, or pipe the key on stdin as above.

Keys are managed at `https://app.incident.io/~/settings/api-keys`.

Environment variable also works: `INCIDENT_API_KEY=<key>`.

Multiple orgs: repeat the setup per alias (`printf '%s' "$KEY" | agent-incident auth add staging`), then pass `--org staging` on any command.
