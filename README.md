# claude-restore

Automated backup of Chuck's AI working environment. Committed nightly by the
Claude scheduled task `nightly-env-backup`.

## Structure

| Folder | Contents |
|--------|----------|
| docker/ | docker-compose.yml and .env.template for the full stack |
| redis/ | Nightly Redis context exports (JSON, dated) |
| chroma/ | Nightly ChromaDB collection snapshots (JSON, dated) |
| n8n/ | n8n workflow exports (JSON) |
| skills/ | Claude/Cowork skill bundles and plugins |
| claude-config/ | Claude settings, plugin files, n8n config (no secrets) |
| restore/ | Restore scripts for new machine setup |

## Stack

| Service | Image | Port |
|---------|-------|------|
| n8n | docker.n8n.io/n8nio/n8n | 5678 |
| ChromaDB | chromadb/chroma:latest | 8000 |
| Redis | redis:latest | 6379 |
| Ollama | (runs locally, not in Docker) | 11434 |

## New Machine Restore

See `restore/restore.ps1` for the automated restore script.
Full instructions: Notes/Tech/AI/Claude Code/New Machine Setup.md in Obsidian.

Quick version:
1. Install Docker Desktop, Git, Python, Node.js, Obsidian, Claude/Cowork
2. Clone this repo to C:\Users\cacha\Documents\Claude\repos
   git clone https://github.com/cacharbe/claude-restore C:\Users\cacha\Documents\Claude\repos
3. Copy docker/.env.template to docker/.env and set N8N_ENCRYPTION_KEY
4. Run: .\restore\restore.ps1
5. Import n8n workflows manually via http://localhost:5678
6. Install .plugin files from claude-config/plugins/
7. Open Obsidian and confirm vault sync

## Manual Backup

To force a backup at any time, type "save" in a Claude/Cowork session.
