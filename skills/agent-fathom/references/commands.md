# agent-fathom command reference

Every command takes the global flags: `--profile/-p`, `--format`, `--timeout`, `--max-retries`,
`--debug`, `--color`, `--expose`.

## meetings

### `meetings list`

The only discovery endpoint. Returns newest-first meeting records.

| Flag | Meaning |
|---|---|
| `--since <ts>` | Created after this ISO 8601 timestamp (`2026-07-01T00:00:00Z`) |
| `--until <ts>` | Created before this timestamp |
| `--recorded-by <email>` | Recorder's email; repeatable, OR within the flag |
| `--team <name>` | Team name; repeatable |
| `--domain <domain>` | Calendar invitees' company domain; repeatable, **exact match** |
| `--invitees all\|internal\|external` | Whether outside attendees were present |
| `--type <name>` | Meeting type name, from `meetings types`. Unknown names return empty |
| `--with <tokens>` | `transcript`, `summary`, `action-items`, `highlights`, `crm`. `transcript` and `summary` are **refused under OAuth** — use `recordings transcript` instead |
| `--match <regex>` / `-m` | Keep meetings whose title **or** calendar title matches (case-insensitive). Auto-enables paging |
| `--attendee <regex>` | Keep meetings with a matching invitee **or** recorder, by name or email. Auto-enables paging |
| `--dedupe` | Collapse the same meeting recorded by more than one person (keyed on `meeting_url` + recording date) |
| `--limit <n>` | **Matches** to emit (default 10) — not records fetched |
| `--cursor <c>` | Resume from a previous page |
| `--all` | Follow `next_cursor` until exhausted or the page cap |

`--with transcript` and `--with summary` move the call into the heavy rate-limit bucket and print a
notice.

Record fields: `title`, `meeting_title`, `meeting_type`, `recording_id`, `url`, `meeting_url`,
`share_url`, `created_at`, `scheduled_start_time`, `scheduled_end_time`, `recording_start_time`,
`recording_end_time`, `calendar_invitees_domains_type`, `shared_with`, `transcript_language`,
`recorded_by`, `calendar_invitees`, plus whatever `--with` added.

Plus a derived **`duration_minutes`** (recorded length, not scheduled) — the only field not from the
API, named so it is obvious.

Nullable in practice: `meeting_title`, `meeting_type`, `meeting_url`, and every `--with` field.
`transcript_language` can be `"unknown"`; `calendar_invitees[].name` can be an email address.

## action-items

`action-items [--assignee <regex>] [--match <regex>] [--open|--completed] [--unassigned] [--since] [--until] [--team] [--type] [--limit] [--cursor]`

Flattens `meetings --with action-items` into one record per commitment, stamped with `recording_id`,
`meeting_title`, `meeting_created_at`, `meeting_url` and `meeting_recorded_by`. Not in the heavy
bucket.

`--assignee` matches name **or** email — match on name: on a live account the assignee had a name on
~99% of items but an email on only ~32%. `--open` and `--completed` are mutually exclusive.
`--limit` counts items, and the walk is bounded by `max_pages`.

### `meetings types`

Lists the org's meeting types with `status` (`active` / `inactive`). Inactive types are no longer
assigned going forward but still appear on historical meetings, so they remain valid `--type`
values.

## recordings

### `recordings summary <recording_id>...`

Heavy bucket. Returns `{summary: {template_name, markdown_formatted}}`. `markdown_formatted` is
always English regardless of the meeting's language.

### `recordings transcript <recording_id>... [--speaker <name>] [--markdown]`

Heavy bucket. Emits **one record per utterance**: `{recording_id, speaker: {display_name,
matched_calendar_invitee_email}, text, timestamp}`. `timestamp` is `HH:MM:SS` from the start of the
recording. `matched_calendar_invitee_email` is null when no invitee matched.

`--speaker` filters on a case-insensitive substring of `display_name`. `--markdown` returns one
record with a rendered `[HH:MM:SS] Name: text` block instead.

### `recordings download request <recording_id>`

Starts asynchronous media generation. Returns `{download_id, recording_id, status}`. Audio-only
recordings may already be `completed`. Its own rate-limit bucket (30/60s).

422 means the recording has no downloadable media.

### `recordings download status <recording_id> <download_id>`

`status` is `processing` | `completed` | `failed` | `expired`. When completed, carries `video` or
`audio` with `{url, content_type, file_size_bytes, expires_at}`.

`url` is redacted by default — it is a signed bearer URL valid ~24h with no authentication.
`--expose video.url` reveals it.

Only the client that created a download can read it. Polling counts against the global bucket.

### `recordings download fetch <recording_id> <download_id> [--out <path>]`

Saves a completed download and prints `{status, recording_id, download_id, path, content_type,
bytes}`. Defaults to `$XDG_CACHE_HOME/agent-fathom/downloads/<recording_id>.<ext>`. The signed URL is
never printed, and the fetch bypasses the API client so the key never reaches the media host (Google
Cloud Storage, a third party).

Emits a notice above 100 MB. Media runs ~7.7 MB per recorded minute, so an hour-long meeting is
around half a gigabyte.

## Shell completion

`completion bash|zsh|fish|powershell`, installed automatically by the Homebrew formula.

Closed-set flags complete their values: `--invitees`, `--with`, `--trigger`, `--include`, `--status`,
`--settings-access`, plus `--profile` from the local config. Comma-joined lists (`--with`,
`--include`, `--trigger`) complete element by element and hide values already chosen.

`--team`, `--type`, `--assignee`, `--attendee` and `--speaker` deliberately do NOT complete: their
values are only knowable from the API, and tab-completion must never spend from the rate-limit
budget. Use `meetings types`, `org teams` and `org members` instead.

## Org

All three live under `org`, which keeps them to one MCP tool rather than three.

| Command | Filters | Notes |
|---|---|---|
| `org teams` | — | `{name, created_at}` |
| `org members` | `--team` | `{name, email, created_at}` |
| `org users` | `--team`, `--status`, `--settings-access` | **account_admin key only**; 403 otherwise |

All three default `--all` on. `users` returns active, then deactivated, then pending members;
invited users have **no `permissions` object** and their `created_at` is the invite date.
`--status invited` cannot be combined with `--settings-access`.

## webhooks

### `webhooks create --url <https-url> [--trigger …] [--include …] --yes`

| Flag | Values |
|---|---|
| `--trigger` | `mine`, `shared-to-me`, `my-team-share`, `team` (default `mine`) |
| `--include` | `transcript`, `summary`, `action-items`, `crm` (default `summary`) |

At least one `--include` is required — Fathom rejects a webhook carrying no content.

Returns the webhook including its `secret`, which is **redacted by default** and shown by Fathom
only once. `--expose secret` prints it.

There is no `webhooks list`: Fathom has no such endpoint. Enumerate them in the Fathom settings UI.

### `webhooks delete <webhook_id> --yes`

### `webhooks verify --id --timestamp --signature [--secret] [--body] [--tolerance]`

Local only; makes no API call. Verifies the Standard Webhooks signature:
HMAC-SHA256 over `<webhook-id>.<webhook-timestamp>.<raw-body>`, keyed by the base64-decoded portion
of the `whsec_…` secret.

- `--secret` falls back to `FATHOM_WEBHOOK_SECRET`, which keeps it off the command line.
- `--body` defaults to stdin. **Must be the raw received bytes.**
- `--tolerance` defaults to 5m; the timestamp check is what stops replays.
- Multiple space-delimited signatures in the header are all tried, so a rotation verifies.

## auth

| Command | Notes |
|---|---|
| `auth add <profile> --form` | Native OS dialog. Also `--api-key`, `--access-token`, `--label`, `--base-url` |
| `auth update <profile> --form` | Rotate the key |
| `auth check [profile]` | One `GET /teams`; reports the host used, `auth_mode`, `inline_meeting_content`, and the rate-limit budget |
| `auth list` | Profile metadata only — never reads a secret |
| `auth default <profile>` | |
| `auth remove <profile>` | Removes the profile and its stored key |

`--api-key` and `--access-token` are alternatives; supplying both is an error. An access token is
stored as given and never refreshed.

`FATHOM_API_KEY` overrides the stored credential and takes precedence over `--profile`.
`FATHOM_ACCESS_TOKEN` (or `FATHOM_BEARER_AUTH`) supplies a bearer token instead; the API key wins if
both are set.
`AGENT_FATHOM_PROFILE` sets the default profile; `AGENT_FATHOM_BASE_URL` overrides the host.
`AGENT_FATHOM_NO_KEYCHAIN=1` (or `LIB_AGENT_NO_KEYCHAIN=1`) forces the file backend.

## config

`config get|set|unset|list` over `timeout_ms`, `max_retries`, `page_limit`, `max_pages`. Plus `config show`
(effective configuration + cache dir) and `config path`.

Precedence is explicit flag > persisted config > built-in default.

## api

`api get <path> [-q key=value]…` — GET only. `-q` is repeatable and preserves duplicate keys, which
is how Fathom's array filters are spelled: `-q 'recorded_by[]=a@x.com' -q 'recorded_by[]=b@x.com'`.
