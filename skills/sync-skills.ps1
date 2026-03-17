# =============================================================================
# sync-skills.ps1 -- Copy Claude skills and plugins into the backup repo
# Run manually or on a schedule via Windows Task Scheduler
# =============================================================================
#
# This script copies the full .skills and .local-plugins directories from
# Claude/Cowork's config folder into the repo so they can be committed to git.
#
# Usage: .\sync-skills.ps1
# =============================================================================

param(
    [string]$RepoRoot = "C:\Users\cacha\Documents\Claude\repos"
)

# --- Locate Claude config directory ---
# Common locations -- script tries each until it finds one
$claudeConfigCandidates = @(
    "$env:APPDATA\Claude",
    "$env:LOCALAPPDATA\Claude",
    "$env:USERPROFILE\.claude"
)

$claudeConfig = $null
foreach ($candidate in $claudeConfigCandidates) {
    if (Test-Path $candidate) {
        $claudeConfig = $candidate
        break
    }
}

if ($null -eq $claudeConfig) {
    Write-Host "ERROR: Could not locate Claude config directory." -ForegroundColor Red
    Write-Host "Tried: $($claudeConfigCandidates -join ', ')"
    Write-Host "Update the claudeConfigCandidates list in this script with the correct path."
    exit 1
}

Write-Host "Claude config found at: $claudeConfig" -ForegroundColor Cyan

# --- Sync .skills ---
$skillsSrc = Join-Path $claudeConfig ".skills"
$skillsDst = Join-Path $RepoRoot "skills\installed"

if (Test-Path $skillsSrc) {
    Write-Host "Syncing skills..."
    robocopy $skillsSrc $skillsDst /MIR /NP /NFL /NDL /NJH | Out-Null
    Write-Host "  OK: skills synced to $skillsDst" -ForegroundColor Green
} else {
    Write-Host "  WARN: .skills directory not found at $skillsSrc" -ForegroundColor Yellow
}

# --- Sync .local-plugins ---
$pluginsSrc = Join-Path $claudeConfig ".local-plugins"
$pluginsDst = Join-Path $RepoRoot "skills\plugins"

if (Test-Path $pluginsSrc) {
    Write-Host "Syncing plugins..."
    robocopy $pluginsSrc $pluginsDst /MIR /NP /NFL /NDL /NJH | Out-Null
    Write-Host "  OK: plugins synced to $pluginsDst" -ForegroundColor Green
} else {
    Write-Host "  WARN: .local-plugins directory not found at $pluginsSrc" -ForegroundColor Yellow
}

# --- Sync Claude settings ---
$settingsSrc = Join-Path $claudeConfig "settings"
$settingsDst = Join-Path $RepoRoot "claude-config\settings"

if (Test-Path $settingsSrc) {
    Write-Host "Syncing Claude settings..."
    if (-not (Test-Path $settingsDst)) { New-Item -ItemType Directory -Path $settingsDst -Force | Out-Null }
    robocopy $settingsSrc $settingsDst /MIR /NP /NFL /NDL /NJH | Out-Null
    Write-Host "  OK: settings synced" -ForegroundColor Green
} else {
    Write-Host "  WARN: settings directory not found at $settingsSrc" -ForegroundColor Yellow
}

# --- Commit and push ---
Write-Host "`nCommitting to git..."
$date = Get-Date -Format "yyyy-MM-dd"
Set-Location $RepoRoot

git add skills\ claude-config\settings\
$status = git status --porcelain
if ($status) {
    git commit -m "sync skills and config $date"
    git push
    Write-Host "  OK: pushed to GitHub" -ForegroundColor Green
} else {
    Write-Host "  No changes to commit" -ForegroundColor Yellow
}

Write-Host "`nDone." -ForegroundColor Cyan
