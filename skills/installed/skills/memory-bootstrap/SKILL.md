---
name: memory-bootstrap
description: >
  Loads context from Redis, ChromaDB, and Obsidian at session start. Summarizes what's known,
  fills gaps with targeted questions, and maintains write-back cadence so nothing is lost
  between sessions.

  Trigger at conversation start when: user mentions a project, says "let's work on X",
  "pick up where we left off", "new task", or uses --project flag. Trigger proactively if
  conversation grows dense without an active project.

  Also watch for save commands at any point: --save, /save, save, checkpoint,
  "save our progress", "commit this", "write this down" — run Forced Save (Step 6b) immediately.

  Run full bootstrap (Steps 1–5) once per conversation, then monitor write-back cadence.
---

# Memory Bootstrap

## Purpose

Every conversation should start with the right context already loaded — not rebuilt from scratch.
This skill loads what's been stored from past sessions, surfaces what matters, fills gaps with
targeted questions, and keeps memory current throughout the conversation so future sessions
can pick up without losing ground.

---

## Detecting Mode: New Project vs. Existing

Before doing anything else, determine which of three modes applies:

### Mode A — `--project <NAME>` flag present

When the user starts a conversation with `--project <PROJECT NAME>` (e.g. `--project Automation and AI`
or `-- project Job Search Pipeline`), extract the project name from everything after the flag.

**Always check for an existing project first** — do not assume this is a new project:

1. Slugify the name and check Redis for `ctx:<slug>:*` keys
2. Check Chroma for collection `ctx-<slug>`
3. Check Obsidian for `Projects/<Name>/<Name> - Working Memory.md`

Run all three checks in parallel.

**If any of these exist → treat as Mode B** (load existing context and resume).
Confirm to the user: "Found existing project **[Name]** — loading context to resume."
Then go to **Step 3: Load Memory**.

**If none exist → treat as new project** and go to **Step 2: Create New Project**.
Confirm: "No existing project found for **[Name]** — setting up a new one."

### Mode B — Continuing an existing project (no flag)

If no `--project` flag but the conversation clearly references an ongoing project (by name,
file path, workflow, or topic with prior memory), infer the project name, then go to
**Step 3: Load Memory**.

### Mode C — No project context

If neither flag nor clear project reference exists, proceed normally without loading memory.
Monitor the conversation; if it grows dense (see **Step 7: Proactive Project Prompt**), offer
to create a project at that point.

---

## Step 1: Identify the Project (Modes A and B)

Derive the project identifiers from the project name:

- **Redis namespace**: `ctx:<project-slug>`
- **Redis keys**: `ctx:<project-slug>:decisions`, `ctx:<project-slug>:facts`, `ctx:<project-slug>:prefs`, `ctx:<project-slug>:state`
- **Chroma collection**: `ctx-<project-slug>`
- **Obsidian note**: `Projects/<Project Name>/<Project Name> - Working Memory.md`

Slugify: lowercase, hyphens for spaces, strip special characters.
Examples: "Job Search Pipeline" → `job-search-pipeline`, "Automation and AI" → `automation-and-ai`

---

## Step 2: Create New Project (Mode A — new only)

When `--project` is detected and no existing project was found, scaffold the full memory suite.
**The stores must be created first, before writing the Obsidian note**, so the note can record
their confirmed config.

**Do these in order:**

1. **Create the Chroma collection** `ctx-<project-slug>` and confirm it succeeded.
2. **Initialize all four Redis keys**:
   - `ctx:<slug>:decisions` → `""`
   - `ctx:<slug>:facts` → `""`
   - `ctx:<slug>:prefs` → `""`
   - `ctx:<slug>:state` → `"Session started <YYYY-MM-DD>. No progress yet."`
3. **Create the Obsidian note** using the template below, with the Memory Infrastructure
   section populated with the actual confirmed store names and creation date.

After scaffolding, confirm:
> "Project **[Name]** initialized. Redis namespace `ctx:<slug>`, Chroma collection
> `ctx-<slug>`, and Obsidian note created. Let's get started."

Then continue to **Step 5: Ask Clarifying Questions**.

---

## Step 3: Load Memory (Modes A-existing and B)

Run these in parallel:

**Redis** — List all keys matching `ctx:<project-slug>:*` and read their values.

Standard key categories:
- `ctx:<project>:decisions` — settled choices that shouldn't be relitigated
- `ctx:<project>:facts` — established facts, thresholds, settings, key numbers
- `ctx:<project>:prefs` — user preferences (tone, format, style, working patterns)
- `ctx:<project>:state` — current progress and what's been completed or is in-flight

**ChromaDB** — Check if collection `ctx-<project-slug>` exists. If it does, query it
using the user's opening message or task description to surface the most semantically
relevant stored content (n_results: 5). Include any Obsidian notes ingested into the
collection — these may contain richer context than Redis keys alone.

**Obsidian** — Check for `Projects/<Project Name>/<Project Name> - Working Memory.md`. If it exists,
read it. Treat it as the authoritative failsafe — if it's more recent than Redis/Chroma
data, prefer it for understanding current state. Also read the `write-back-interval`
from its frontmatter and use that value for the session (default: 15 if not present).

### Store verification and repair

After loading, **verify that both stores actually exist**:

- If Redis keys are missing → create them now (same initialization as Step 2)
- If Chroma collection is missing → create it now
- If the Obsidian note is missing or lacks a Memory Infrastructure section → create/update it

If any store had to be created or repaired, append a note to the Obsidian Session Log:
> `[<date>] Store repair: created missing <Redis keys / Chroma collection> on resume.`

If nothing is found anywhere, note that plainly and continue to Step 5.

---

## Step 4: Summarize What You Found (Modes A-existing and B)

After loading, give the user a brief summary — 3–5 bullet points, nothing more.
The goal is to confirm you have the right context, not to recite everything you loaded.

Example format:
> **Context loaded — [Project Name]:**
> - Last session: [topic or date from state]
> - Key decisions: [1–2 most important settled choices]
> - Status: [where things left off, what's next]
> - ⚠ [Any gaps, stale data, or conflicts worth flagging]

If the loaded context contains a conflict (e.g., Redis says one thing, Obsidian says
another), surface it and ask which to trust before proceeding.

---

## Step 5: Ask Clarifying Questions (All modes)

Before starting any work, ask 2–3 targeted questions to fill the most important gaps.
Focus on things where the answer will meaningfully change what you do.

**Ask about:**
- Decisions not yet settled that will affect this session's work
- Things that may have changed since last session
- Priorities or constraints not evident from the loaded context
- Anything where an assumption would send the work in the wrong direction

**Don't ask about:**
- Things already answered in the loaded context
- Stylistic preferences you can reasonably infer from prior sessions
- Details you can look up or that won't affect the outcome

No more than 3 questions at once. Wait for answers before asking more.

---

## Step 6: Write-back Cadence

Once the conversation is underway, persist context on the following schedule.
Memory that isn't written back is memory that gets lost.

### Write-back interval

The default interval is **15 exchanges**. This is stored in the Obsidian note's
frontmatter as `write-back-interval: 15` and can be updated at any time — either
because the user asks, or because you judge the conversation warrants it (dense
technical sessions may benefit from 10; lighter ones can stretch to 20).

To change it during a session, update the frontmatter value and confirm:
> "Write-back interval updated to [N] exchanges."

### When to write back automatically

Write back when any of these conditions are met:

1. **Every N exchanges** — count turns; write back at N, 2N, 3N, etc., using the
   current `write-back-interval` value
2. **When a meaningful unit completes** — a decision is settled, a segment approved,
   a task finished, a phase wrapped up
4. **When context is getting long** — if the conversation has been running a long time
   or you notice context compressing, write back proactively before anything is lost
5. **At natural stopping points** — end of session, before switching topics

When writing back automatically, say: `Saving context...` and briefly note what was stored (one line).

---

## Step 6b: Forced Save (explicit save command)

### Trigger phrases

Immediately run this procedure when the user says any of the following, regardless of
where in the conversation it appears:

`--save` · `/save` · `save` · `checkpoint` · `save our progress` · `commit this` · `write this down`

Do not wait for the next natural write-back interval. Execute the full save now.

### Save procedure

Run all three stores in parallel. Do not skip a store because "nothing changed" —
the point of a forced save is a full, reliable snapshot at a known moment.

**1. Redis** — Overwrite all four keys with the current session's best understanding:
- `ctx:<slug>:decisions` — all settled choices from this session, including any new ones
- `ctx:<slug>:facts` — all confirmed facts, settings, key values in play
- `ctx:<slug>:prefs` — any preference or convention updates from this session
- `ctx:<slug>:state` — a concise statement of current progress and what's next

**2. Chroma** — Add a timestamped session-snapshot document to `ctx-<project-slug>`:
- Document text: a 3–5 sentence summary of what was accomplished this session,
  key decisions made, and current status
- ID: `snapshot-<YYYY-MM-DD>-<HHMM>` (use current date/time)
- Metadata: `{ "project": "<slug>", "topic": "session-snapshot", "date": "<YYYY-MM-DD>", "type": "snapshot" }`

**3. Obsidian** — Append a dated Session Log entry to the working memory note:
```
### <YYYY-MM-DD> — Forced save / checkpoint
- [bullet summary of what was accomplished]
- [any new decisions]
- [current status / what's next]
```
Also update `last-updated` in the frontmatter to today's date.

### Save confirmation

After all three writes complete, respond with:

> `Context saved.`
> - **Redis**: decisions · facts · prefs · state updated
> - **Chroma**: snapshot `snapshot-<date>-<time>` added to `ctx-<slug>`
> - **Obsidian**: Session Log entry appended
>
> _[One sentence summarizing what was captured — e.g. "Captured Exa integration decisions and current workflow state."]_

If any store write fails, report it clearly rather than silently skipping:
> `⚠ Obsidian write failed — Redis and Chroma saved successfully. [Error detail]`

---

## Step 7: Proactive Project Prompt (Mode C only)

If no project was established at the start, monitor the conversation. If it reaches
**20 exchanges** and is clearly substantive (not a quick one-off question), ask once:

> "This is turning into a solid working session — want me to set up a project for it
> so we can pick it up later? I'd suggest calling it **[inferred name]**."

If the user says yes, treat it as a `--project` request and run Step 2 at that point.
If the user says no or doesn't engage, don't ask again.

---

## Obsidian Note Template

### Creating a new note (Step 2 or first run)

> **Important**: Always use `obsidian_append_content` to create or fully replace this note.
> Never use `obsidian_patch_content` on frontmatter fields — it embeds content inside the
> field's value rather than corrupting the YAML.
>
> The Memory Infrastructure section must be filled with the **actual confirmed** store names
> and creation date — not placeholders. Only write the note after the stores are confirmed created.

```markdown
---
title: <Project Name> - Working Memory
date: <YYYY-MM-DD>
type: Project Memory
project: <Project Name>
last-updated: <YYYY-MM-DD>
redis-namespace: ctx:<project-slug>
chroma-collection: ctx-<project-slug>
write-back-interval: 15
---

# [[<Project Name> - Working Memory]]

## Project Summary

## Status

## Memory Infrastructure

| Store   | Resource                                     | Keys / Details                                    | Created      |
|---------|----------------------------------------------|---------------------------------------------------|--------------|
| Redis   | namespace: `ctx:<project-slug>`              | `decisions` · `facts` · `prefs` · `state`        | <YYYY-MM-DD> |
| Chroma  | collection: `ctx-<project-slug>`             | semantic search, session summaries, snapshots     | <YYYY-MM-DD> |
| Obsidian| `Projects/<Name>/<Name> - Working Memory.md` | human-readable failsafe, authoritative on conflict| <YYYY-MM-DD> |

## Key Decisions
- (none yet)

## Open Questions
- (to be filled in from conversation)

## Session Log

```

### Updating an existing note

Append a new Session Log entry. Update Status, Key Decisions, and Open Questions
only for things that actually changed. Update `last-updated` in frontmatter.
If the write-back interval changed this session, update `write-back-interval` too.
If stores were repaired or created this session, update the Memory Infrastructure table dates.

---

## Quick Reference

| Store | Key / Location | Use for |
|-------|----------------|---------|
| Redis | `ctx:<project>:decisions` | Settled choices |
| Redis | `ctx:<project>:facts` | Numbers, thresholds, settings |
| Redis | `ctx:<project>:prefs` | Tone, format, style preferences |
| Redis | `ctx:<project>:state` | Current progress |
| Chroma | `ctx-<project-slug>` | Longer content, semantic retrieval, snapshots |
| Obsidian | `Projects/<Name>/<Name> - Working Memory.md` | Human-readable failsafe, config |

## Save Command Quick Reference

| Trigger | Action |
|---------|--------|
| `--save` or `/save` or `save` | Full forced save to Redis + Chroma + Obsidian |
| `checkpoint` | Same as above |
| `save our progress` | Same as above |
| `commit this` | Same as above |
| `write this down` | Same as above |
