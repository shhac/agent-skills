---
name: agent-fathom
description: |
  Search and read Fathom meeting recordings: transcripts, AI summaries, action items, highlights, attendees, CRM matches, meeting types, teams, and users. Also manages and verifies Fathom webhooks. Use when:
  - Finding what was said or agreed in a meeting, or what a customer asked for
  - Pulling a transcript, summary, action items, or highlights for a recording
  - Finding meetings by date, company domain, recorder, team, or meeting type
  - Downloading a meeting's video or audio file
  - Listing Fathom teams, team members, or users and their permissions
  - Finding meetings by title, attendee, company, date, recorder, team, or meeting type
  - Listing or filtering action items and commitments from meetings
  - Creating, deleting, or signature-verifying a Fathom webhook
  Triggers: "fathom", "action items", "what did we commit to", "outstanding actions", "meeting notes", "meeting transcript", "call transcript", "meeting recording", "AI notetaker", "call summary", "action items from the call", "what did we agree", "what did the customer say", "recording_id", "fathom.video", "meeting highlights", "call recording"
allowed-tools: Bash(agent-fathom *) Bash(mockfathom *) Read Grep Glob
---

# agent-fathom

Use `agent-fathom` to answer questions about recorded meetings: what was said, what was agreed, who
was there, and what a customer actually asked for.

Run `agent-fathom usage` first. It prints the command map organized by question, plus the rate-limit
strategy.

## The one thing that shapes every workflow

**Fathom has no meeting-by-id and no search.** There is one discovery endpoint — `meetings list` —
and its filters are the whole query language. Nothing gets you from a phrase back to a meeting.

So every investigation has the same shape:

1. `meetings list` with filters, to get `recording_id`s.
2. `recordings transcript` / `recordings summary` on the ones that matter.

`--match` gives you title search by paging and filtering locally — it is the closest thing to a find
verb. But "find the meeting where we discussed pricing" still is not answerable: there is no content
search. Narrow by title, attendee, date, domain, recorder, team or type — then read.

### Searching, by cost

| | How | Cost |
|---|---|---|
| Server-side | `--since/--until`, `--recorded-by`, `--team`, `--domain`, `--invitees`, `--type` | 1 request/page, exact |
| Client-side | `--match`, `--attendee`, `--dedupe` | Free — filters data the page already returned |
| Content | read `recordings transcript` per candidate | Heavy bucket; only on a narrowed set |

Client-side filters run *inside* the paging loop, so `--limit` counts **matches**, not records
fetched, and `--match`/`--attendee` auto-follow the cursor. Four traps worth knowing:

- **Titles drift.** A real series appeared as both "Collab" and "Colab"; searching the obvious
  spelling found half of it. Match loosely: `--match 'produc.*(collab|colab)'`.
- **The same meeting appears once per recorder.** Two colleagues recording one call produce two
  records with different `recording_id`s. Pass `--dedupe` before counting anything.
- **A walk can stop early.** It reports the page budget on stderr with a resume cursor. After that
  notice, empty means "not in the window I searched" — say so rather than "it does not exist".
- **An unknown `--type` returns an empty list**, not an error. Check `meetings types` first.

## Action items

```
agent-fathom action-items --open                        # everything outstanding
agent-fathom action-items --assignee "Jane" --open      # one person's commitments
agent-fathom action-items --unassigned --open           # nobody picked these up
agent-fathom action-items --match "invoice|pricing"     # by what was committed to
```

One record per action item, stamped with `recording_id`, `meeting_title`, `meeting_created_at` and
`recording_playback_url` (jumps to the moment it was said). Not in the heavy bucket, so it is cheap.

**Match assignees by NAME, not email.** On a real account the assignee carried a name on ~99% of
items but an email on only ~32% — `--assignee "someone@company.com"` will find almost nothing while
`--assignee "Their Name"` works. Most items have no assignee at all, which is what `--unassigned` is
for.

## Safety

- **Never accept a pasted API key or access token in chat.** Ask the user to run
  `agent-fathom auth add <profile> --form`, which collects it in a native OS dialog. If you are
  running headlessly, say so and ask them to run it on their own machine.
- **Meeting content is sensitive.** Transcripts and summaries routinely contain commercially and
  personally sensitive material. Treat the output as you would the recording itself: do not paste it
  into shared channels, tickets, or documents unless the user asked you to.
- **Empty is ambiguous.** Fathom API keys are **user-scoped**: a key only reaches meetings its owner
  recorded or was shared with. An empty result can mean "not shared with this key" as easily as "did
  not happen". Say which you know and which you are assuming — never report "there was no such
  meeting" from an empty list.
- **`users` needs an account_admin key** and 403s otherwise, while everything else works. That is a
  permission fact, not a broken credential.
- **Webhooks are the only writes**, both need `--yes`, and neither is available as an MCP tool.
  Creating one ships every future meeting's content to a URL, and deleting it later does not recall
  what already fired. Confirm with the user before proposing one.

## Two auth schemes

`agent-fathom auth check` reports `auth_mode`: `api_key` or `oauth`. It matters for exactly one
thing, reported as `inline_meeting_content`:

- **`api_key`** — `meetings list --with transcript|summary` works.
- **`oauth`** — it does not, and is refused up front. Fathom ignores those parameters for OAuth apps,
  so sending them would return meetings with the content silently missing. Fetch per recording
  instead: `recordings transcript <recording_id>`.

Everything else behaves identically. If you hit the refusal, do not retry it — switch to the
per-recording read.

## Cost — climb down the ladder, don't jump to the bottom

The cheap and expensive calls differ by ~1000x, and you cannot see which you asked for until you have
paid for it. Measured on a real account:

| Rung | Cost | Use when |
|---|---|---|
| `meetings list` | ~460 tok/meeting | You need to find or filter meetings |
| `action-items` | ~275 tok/meeting — **30x cheaper than a transcript** | The question is "what did we commit to?" |
| `recordings summary <id>` | ~1–3k tok | You need the gist of one call |
| `recordings transcript <id>` | ~500 tok per recorded minute (an hour ≈ 31k) | You need **verbatim** wording |

**Never** `meetings list --with transcript` — ~285,000 tokens at the default page size of 10.

**Fathom has exactly one summary per recording.** The template is org configuration, not a
per-request option, so there is no shorter summary to request. The cheaper rungs are different
commands, not different flags.

Prefer the summary unless the question genuinely needs the words someone used. Both cost the same
single heavy-bucket request, so the transcript buys you nothing on rate limit and costs 8x the
context. If you do need a transcript, `--speaker` narrows it and `--markdown` drops the per-utterance
JSON envelope, which is about 2.8x the size of the speech itself.

## Rate limits — plan before you loop

Fathom allows 60 requests/minute, but transcript and summary reads are in a **heavy bucket of
30/minute that drops to 5/minute under load**.

**List wide, fetch narrow.** Do this:

```
agent-fathom meetings list --domain acme.com --since 2026-07-01T00:00:00Z
# read the titles/attendees, pick the 2 that matter, then:
agent-fathom recordings transcript 123456789
```

Not this:

```
agent-fathom meetings list --all --with transcript   # 429 waiting to happen
```

`--with transcript|summary` prints a notice on stderr when it moves you into the heavy bucket. Take
it seriously — it is telling you your remaining budget just dropped by up to 12×.

## Finding meetings

```
agent-fathom meetings list --since 2026-07-01T00:00:00Z --until 2026-08-01T00:00:00Z
agent-fathom meetings list --domain acme.com               # by the other company's domain
agent-fathom meetings list --recorded-by alice@acme.com    # by who recorded it
agent-fathom meetings list --team Sales
agent-fathom meetings list --type "Quarterly Business Review"
agent-fathom meetings list --invitees external             # only meetings with outside attendees
```

Filters combine, and the repeatable ones (`--domain`, `--recorded-by`, `--team`) are OR within a
flag. `--type` takes a name from `agent-fathom meetings types` — an unknown name silently returns an
empty list, so check the list rather than guessing.

Timestamps are ISO 8601 with a `Z`: `2026-07-01T00:00:00Z`.

Add content inline only when you need it for every result: `--with summary`, `--with action-items`,
`--with highlights`, `--with crm`, `--with transcript`.

Paging: 10 records by default. `--limit N` to change it, `--all` to follow the cursor (capped, with a
notice and a resume cursor when it stops), `--cursor` to resume. Raise the depth with
`agent-fathom config set max_pages <n>` on a busy account.

Every meeting also carries a derived **`duration_minutes`** (from the recording times, not the
scheduled ones) so you can total time without parsing timestamps.

## Reading a recording

```
agent-fathom recordings summary 123456789
agent-fathom recordings transcript 123456789
agent-fathom recordings transcript 123456789 --speaker "Jane"   # just one person's lines
agent-fathom recordings transcript 123456789 --markdown         # readable block
```

Transcripts stream **one utterance per line**, each stamped with its `recording_id`. Prefer
`--speaker` or piping to `head` over reading a whole hour-long transcript into context.

`speaker.matched_calendar_invitee_email` is null when Fathom could not match a speaker to an
invitee — do not assume every line has an identified email.

## Media files

```
agent-fathom recordings download request 123456789            # returns a download_id
agent-fathom recordings download status  123456789 dl_...     # poll until "completed"
agent-fathom recordings download fetch   123456789 dl_...     # saves the file, prints the path
```

Generation is asynchronous: the first status poll usually says `processing`. The signed URL in a
completed download is **a credential** (~24h, no auth needed) and is redacted by default — use
`fetch` to get the bytes rather than exposing the URL. It points at Google Cloud Storage, not
Fathom, which is exactly why the API key must never be sent with it.

**Media is big: roughly 7.7 MB per recorded minute.** A 17-minute call is ~130 MB; an hour is ~500 MB.
`fetch` warns above 100 MB. Check `duration_minutes` before fetching in bulk, and do not download a
batch of meetings on a vague instruction — confirm with the user first.

## Org lookups

```
agent-fathom org teams
agent-fathom org members --team Sales
agent-fathom org users --settings-access account_admin   # needs an account_admin key
```

## Webhooks

```
agent-fathom webhooks create --url https://example.com/hook --include summary,action-items --yes
agent-fathom webhooks delete wh_abc123 --yes
agent-fathom webhooks verify --id "$ID" --timestamp "$TS" --signature "$SIG" --body payload.json
```

`--trigger` picks which recordings fire it: `mine`, `shared-to-me`, `my-team-share`, `team`.

The signing secret is shown **once** by Fathom and is redacted by default; re-run with
`--expose secret` and tell the user to store it. There is no `webhooks list` — Fathom has no such
endpoint, so an id must come from the settings UI or from the create response.

`verify` needs the **raw** body bytes. Re-serializing parsed JSON reorders keys and the signature
covers bytes, so a re-encoded payload always fails.

## Reading the output

NDJSON by default: one record per line, then `{"@pagination": {...}}`. `has_more: true` means there
is more behind `next_cursor` — including when a walk stopped early on `--limit`.

Errors are `{error, fixable_by, hint}` on stderr. `fixable_by` tells you what to do:

- `agent` — fix your input and retry (bad filter value, unknown id, malformed timestamp)
- `human` — stop and ask (rejected key, missing permission, 403)
- `retry` — transient (429, 5xx); the hint says how long

`{"notice": ...}` lines on stderr are not failures — they are facts that should change your next
call (heavy bucket entered, page cap reached, secret redacted).

## Escape hatch

```
agent-fathom api get /meetings -q include_summary=true -q 'recorded_by[]=a@acme.com'
```

GET only, by design.
