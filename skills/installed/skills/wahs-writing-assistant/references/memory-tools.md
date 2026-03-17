# Memory Tools -- With All Her Senses

## Redis

Namespace: `ctx:wahs:*`

| Key | Contains |
|-----|---------|
| `ctx:wahs:decisions` | Settled creative and structural choices -- do not contradict |
| `ctx:wahs:facts` | Established lore facts, confirmed details, key numbers |
| `ctx:wahs:prefs` | Chuck's working style preferences as established over sessions |
| `ctx:wahs:state` | Current progress, what's in flight, what's next |

Read all four keys at session start (memory-bootstrap handles this).
Write back when decisions are settled or facts are confirmed.

## ChromaDB -- chroma-creative MCP

Use `mcp__chroma-creative__*` tools for ALL WAHS Chroma operations.
Do NOT use `mcp__chroma__*` -- that server uses 384-dim embeddings and will fail
on these collections.

| Collection | Documents | Contains |
|-----------|-----------|---------|
| `wahs-manuscript` | 55 | Chunked manuscript from Prologue through Part Three |
| `wahs-research` | 368 | *The Hustler* by Maija Soderholm (368 chunks, fully indexed) |

### Useful query patterns

Finding relevant manuscript passages:
```
collection: wahs-manuscript
query: "Rachael's breath technique and how she conceals her power"
n_results: 3-5
```

Finding martial / teaching context from The Hustler:
```
collection: wahs-research
query: "blade fighting distance and timing"
n_results: 3-5
```

Note -- as of 2026-03-15, wahs-research contains ONLY The Hustler by Maija Soderholm.
The following are in the vault (Research/Books/) but not yet indexed:
- The Liar, The Cheat and The Thief (Soderholm, .txt)
- The Spy and the Rodeo Clown (Soderholm, .txt)
- The 48 Laws of Power (Robert Greene, .pdf)
- The Gift of Fear (de Becker, .pdf)
- The Moscow Rules (.md)

Until these are indexed, use obsidian-novel to read them directly, or note the gap
and ask Chuck to prioritize a re-indexing session.

Filtering by section (metadata filter):
```
where: {"section": "Embercall"}
```

Filtering by part:
```
where: {"part": "PART ONE"}
```

### Manuscript chunk metadata structure
```json
{
  "title": "With All Her Senses",
  "section": "Chapter Name",
  "part": "PART ONE",
  "source": "manuscript",
  "chunkIndex": 5,
  "subChunk": 0
}
```

## Obsidian -- Working Memory Note

Vault: `obsidian-secondbrain`
Path: `Projects/With All Her Senses Writing Assistant/With All Her Senses Writing Assistant - Working Memory.md`

This is the human-readable failsafe. It contains the full memory store table,
chapter map, character roster, key decisions, and session log. If Redis and Chroma
are both cold, this note has enough to reconstruct context. Append session log
entries at write-back time; update Status and Key Decisions only when things change.
