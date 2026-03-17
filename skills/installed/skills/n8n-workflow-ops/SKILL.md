---
name: n8n-workflow-ops
description: "Use this skill whenever you are about to modify n8n workflows using the n8n MCP tools — specifically n8n_update_partial_workflow, n8n_create_workflow, or n8n_get_workflow. Critical patterns to avoid repeat failures: updateNode requires nodeId (not name) and an updates wrapper; addConnection uses display names (not IDs); Code node sandboxes block fetch/URL/process.env. Trigger on: updating nodes, adding connections, creating workflows, writing Code node JavaScript, or diagnosing n8n MCP errors."
---

# n8n Workflow Operations — Correct Patterns

This skill exists because specific mistakes have caused repeated failures when using the n8n MCP tools. Read the failure patterns before making any workflow changes.

---

## Before Any Update: Get Node IDs First

Always fetch the workflow before modifying it. You need the actual node `id` values (not display names) for `updateNode`, and the display names for `addConnection`.

```
n8n_get_workflow(id: "WORKFLOW_ID", mode: "structure")
```

The response contains each node's `id` (e.g. `"search-linkedin"`) and `name` (e.g. `"Search LinkedIn Jobs"`). Keep both on hand.

---

## updateNode — Two Required Fields That Are Easy to Get Wrong

### ✅ Correct format
```json
{
  "type": "updateNode",
  "nodeId": "search-linkedin",
  "updates": {
    "parameters": {
      "jsCode": "..."
    }
  }
}
```

### ❌ Two failure modes observed in practice

**Failure 1** — Using `name` instead of `nodeId`, and putting `parameters` directly on the operation:
```json
{
  "type": "updateNode",
  "name": "Search LinkedIn Jobs",
  "parameters": { "jsCode": "..." }
}
```
Error: *"Missing required parameter 'updates'. The updateNode operation requires an 'updates' object..."*

**Failure 2** — Using `name` with `updates`, but `name` is ignored; only `nodeId` is valid:
```json
{
  "type": "updateNode",
  "name": "Search LinkedIn Jobs",
  "updates": { "parameters": { "jsCode": "..." } }
}
```
Error: *"Node not found for updateNode: \"\". Available nodes: ..."* — the node ID is resolved as empty string.

**The rule:** `nodeId` = the node's `id` field from the workflow JSON (short kebab-case string). `name` is the display name shown in the UI and is NOT accepted by `updateNode`. Use `nodeId` always.

---

## addConnection — Uses Display Names, Not IDs

Unlike `updateNode`, `addConnection` uses the node's `name` (display name), not `nodeId`.

### ✅ Correct format
```json
{
  "type": "addConnection",
  "source": "Search LinkedIn Jobs",
  "target": "Any New Jobs?"
}
```

### For IF node branches
```json
{
  "type": "addConnection",
  "source": "Any New Jobs?",
  "target": "Fetch Job and Score Fit",
  "branch": "false"
}
```
`branch: "true"` = first output (true path), `branch: "false"` = second output (false path).

---

## Code Node Sandbox — What's Available and What Isn't

n8n Code nodes run in a restricted Node.js sandbox. These restrictions cause silent failures if assumed away.

| Available | Not Available |
|---|---|
| `require('https')` | `fetch()` |
| `require('http')` | `URL` constructor |
| `require('fs')` *(needs env var)* | `process.env` |
| `require('path')` *(needs env var)* | `Buffer` (sometimes) |
| `$input`, `$json`, `$items` | `axios`, `node-fetch` |
| `await` (top-level) | `import` syntax |

For `fs` and `path` to work, n8n must be started with:
```
NODE_FUNCTION_ALLOW_BUILTIN=fs,path,crypto,http,https
```

### Making HTTP requests in Code nodes
```javascript
var https = require('https');

function httpGet(hostname, path) {
  return new Promise(function(resolve, reject) {
    var opts = { hostname: hostname, port: 443, path: path, method: 'GET',
      headers: { 'User-Agent': 'Mozilla/5.0' } };
    var req = https.request(opts, function(res) {
      var chunks = [];
      res.on('data', function(d) { chunks.push(d.toString()); });
      res.on('end', function() { resolve({ status: res.statusCode, text: chunks.join('') }); });
    });
    req.on('error', reject);
    req.end();
  });
}

var result = await httpGet('api.example.com', '/endpoint');
```

### Reading config/secrets from filesystem
```javascript
var fs = require('fs');
var config = {};
try {
  config = JSON.parse(fs.readFileSync('/home/node/.n8n/ai-config.json', 'utf8'));
} catch(e) {}
var apiKey = config.my_key || '';
```

---

## Config Flag Pattern (Established Convention)

When building Code nodes that need test/production toggling, always put flags at the top in a clearly marked CONFIG block:

```javascript
// ── CONFIG ──────────────────────────────────────────────────────────────────
var SKIP_DEDUP = true;          // true = return all found jobs; false = skip seen
var FORCE_TRIGGER = false;      // true = bypass score threshold; false = enforce 70%
var MAX_ITEMS_PER_RUN = null;   // null = no cap (production); 10 = testing cap
// ────────────────────────────────────────────────────────────────────────────
```

**Key convention:** `null` means "no limit / production default". Only set to a number when explicitly testing with a cap. Never hardcode a numeric cap as the permanent default.

For cap logic, always guard with a truthiness check:
```javascript
// ✅ Correct — null means no cap
if (MAX_ITEMS_PER_RUN && items.length > MAX_ITEMS_PER_RUN) {
  items = items.slice(0, MAX_ITEMS_PER_RUN);
}

// ❌ Wrong — fails silently when null (null > 10 === false, but is confusing)
if (items.length > MAX_ITEMS_PER_RUN) { ... }
```

---

## Workflow Update Checklist

Before calling `n8n_update_partial_workflow`:

1. ✅ Fetch workflow first to get node `id` values
2. ✅ Use `nodeId` (not `name`) in `updateNode` operations
3. ✅ Wrap property changes in `updates: { parameters: { ... } }`
4. ✅ Use display `name` (not `id`) in `addConnection` operations
5. ✅ Verify sandbox compatibility of any new JavaScript (no fetch, no URL, no process.env)
6. ✅ Check `MAX_ITEMS_PER_RUN` and similar flags default to `null`, not a hardcoded number
