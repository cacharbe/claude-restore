# =============================================================================
# init-repos.ps1
# One-time setup script for Chuck's AI environment backup repo.
# Run from PowerShell as: .\init-repos.ps1 -GitHubRepo "https://github.com/YOUR_USERNAME/YOUR_REPO.git"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubRepo
)

$RepoRoot = "C:\Users\cacha\OneDrive\Documents\Claude\repos"

Write-Host "Setting up backup repo at: $RepoRoot" -ForegroundColor Cyan

# --- Create folder structure ---
$folders = @(
    "redis",        # Redis context exports (JSON, dated)
    "chroma",       # ChromaDB collection snapshots (JSON, dated)
    "n8n",          # n8n workflow exports (JSON)
    "docker",       # Docker Compose files and env templates
    "skills",       # Full skill directories (zipped)
    "claude-config\settings",   # Claude / Cowork settings
    "claude-config\plugins",    # Installed plugin files
    "claude-config\n8n",        # n8n config files (ai-config.json, etc.)
    "restore"       # Restore scripts
)

foreach ($folder in $folders) {
    $path = Join-Path $RepoRoot $folder
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Host "  Created: $folder" -ForegroundColor Green
    } else {
        Write-Host "  Already exists: $folder" -ForegroundColor Yellow
    }
}

# --- Write .gitignore ---
$gitignore = @"
# Keep folder structure but ignore large or sensitive files
*.log
*.tmp
.DS_Store
Thumbs.db

# Keep dated backups but cap at last 30 days (manual pruning)
# redis/redis-2025*.json  # uncomment to exclude old years

# Never commit credentials directly
claude-config/n8n/ai-config.json
"@
Set-Content -Path (Join-Path $RepoRoot ".gitignore") -Value $gitignore
Write-Host "  Created: .gitignore" -ForegroundColor Green

# --- Write README ---
$readme = @"
# chuck-workspace-backup

Automated nightly backup of Chuck's AI working environment.

## Contents

| Folder | Contents |
|--------|----------|
| redis/ | Redis context exports (JSON, dated) |
| chroma/ | ChromaDB collection snapshots (JSON, dated) |
| n8n/ | n8n workflow exports (JSON) |
| docker/ | Docker Compose files for the full stack |
| skills/ | Claude/Cowork skill bundles (zipped) |
| claude-config/ | Claude settings, plugins, and n8n config |
| restore/ | Restore scripts for new machine setup |

## Restore Instructions

See restore/README.md or the Obsidian note:
Notes/Tech/AI/Claude Code/New Machine Setup.md

## Backup Schedule

Nightly at 2am via Claude scheduled task (nightly-env-backup).
Manual trigger: type "save" or "--save" in any Claude/Cowork session.

## Stack

- Redis (port 6379)
- ChromaDB (port 8000)
- n8n (port 5678)
- Ollama (port 11434)
"@
Set-Content -Path (Join-Path $RepoRoot "README.md") -Value $readme
Write-Host "  Created: README.md" -ForegroundColor Green

# --- Add placeholder .gitkeep files so folders are tracked ---
foreach ($folder in $folders) {
    $keepFile = Join-Path $RepoRoot $folder ".gitkeep"
    if (-not (Test-Path $keepFile)) {
        New-Item -ItemType File -Path $keepFile -Force | Out-Null
    }
}

# --- Initialize git and connect remote ---
Set-Location $RepoRoot

if (-not (Test-Path (Join-Path $RepoRoot ".git"))) {
    git init
    Write-Host "  Git repo initialized" -ForegroundColor Green
} else {
    Write-Host "  Git repo already initialized" -ForegroundColor Yellow
}

git add .
git commit -m "initial repo scaffold"

git remote remove origin 2>$null
git remote add origin $GitHubRepo
git branch -M main
git push -u origin main

Write-Host ""
Write-Host "Done! Repo is live at: $GitHubRepo" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Paste your Docker Compose files into docker/" -ForegroundColor Gray
Write-Host "  2. Copy your n8n ai-config.json to claude-config/n8n/ (keep out of git -- see .gitignore)" -ForegroundColor Gray
Write-Host "  3. Run the skills backup script (skills-backup.ps1) to populate skills/" -ForegroundColor Gray
