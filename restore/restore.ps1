# =============================================================================
# restore.ps1 -- Full environment restore from backup repo
# Run from PowerShell as: .\restore.ps1
# Prerequisites: Docker Desktop running, Git installed, repo cloned
# =============================================================================

param(
    [string]$RepoRoot = "C:\Users\cacha\Documents\Claude\repos",
    [string]$RedisHost = "localhost",
    [int]$RedisPort = 6379,
    [string]$ChromaHost = "http://localhost:8000",
    [string]$N8nHost = "http://localhost:5678"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    WARN: $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "    FAIL: $msg" -ForegroundColor Red }

# =============================================================================
# STEP 1 -- Start Docker services
# =============================================================================
Write-Step "Starting Docker services"

$dockerDir = Join-Path $RepoRoot "docker"
if (-not (Test-Path (Join-Path $dockerDir ".env"))) {
    Write-Fail ".env file not found in $dockerDir"
    Write-Host "  Copy docker/.env.template to docker/.env and fill in N8N_ENCRYPTION_KEY before running restore." -ForegroundColor Red
    exit 1
}

Set-Location $dockerDir
docker compose up -d
Write-OK "Containers started"

# Wait for services to be healthy
Write-Host "  Waiting for services to be ready..."
Start-Sleep -Seconds 15

$retries = 0
while ($retries -lt 12) {
    try {
        $redisReady = (docker exec redis-cache redis-cli ping 2>$null) -eq "PONG"
        if ($redisReady) { break }
    } catch {}
    $retries++
    Start-Sleep -Seconds 5
}

if ($retries -ge 12) {
    Write-Fail "Redis did not become healthy in time. Check: docker logs redis-cache"
    exit 1
}
Write-OK "All services healthy"

# =============================================================================
# STEP 2 -- Restore Redis
# =============================================================================
Write-Step "Restoring Redis context"

$redisDir = Join-Path $RepoRoot "redis"
$latestRedis = Get-ChildItem $redisDir -Filter "redis-*.json" | Sort-Object Name | Select-Object -Last 1

if ($null -eq $latestRedis) {
    Write-Warn "No Redis backup files found in $redisDir -- skipping"
} else {
    Write-Host "  Using: $($latestRedis.Name)"
    $redisData = Get-Content $latestRedis.FullName | ConvertFrom-Json
    $keyCount = 0
    foreach ($prop in $redisData.PSObject.Properties) {
        $key = $prop.Name
        $value = $prop.Value
        if ($value -is [string]) {
            docker exec redis-cache redis-cli SET $key $value | Out-Null
        } else {
            $json = $value | ConvertTo-Json -Compress
            docker exec redis-cache redis-cli SET $key $json | Out-Null
        }
        $keyCount++
    }
    Write-OK "Restored $keyCount Redis keys"
}

# =============================================================================
# STEP 3 -- Restore ChromaDB
# =============================================================================
Write-Step "Restoring ChromaDB collections"

$chromaDir = Join-Path $RepoRoot "chroma"
$latestChroma = Get-ChildItem $chromaDir -Filter "chroma-*.json" | Sort-Object Name | Select-Object -Last 1

if ($null -eq $latestChroma) {
    Write-Warn "No ChromaDB backup files found in $chromaDir -- skipping"
} else {
    Write-Host "  Using: $($latestChroma.Name)"
    Write-Host "  Restoring ChromaDB via Python..."

    $restoreScript = Join-Path $RepoRoot "restore\restore_chroma.py"
    if (Test-Path $restoreScript) {
        python $restoreScript --backup $latestChroma.FullName --host $ChromaHost
        Write-OK "ChromaDB restore complete"
    } else {
        Write-Warn "restore_chroma.py not found -- manual restore required"
        Write-Host "  Backup file is at: $($latestChroma.FullName)"
    }
}

# =============================================================================
# STEP 4 -- Restore n8n workflows
# =============================================================================
Write-Step "Restoring n8n workflows"

$n8nDir = Join-Path $RepoRoot "n8n"
$workflowFiles = Get-ChildItem $n8nDir -Filter "*.json"

if ($workflowFiles.Count -eq 0) {
    Write-Warn "No n8n workflow files found in $n8nDir -- skipping"
} else {
    Write-Host "  Found $($workflowFiles.Count) workflow file(s)"
    Write-Host "  Import via n8n UI: Settings -> Import workflow -> select each file in $n8nDir"
    Write-Host "  Or run: python restore\restore_n8n.py --n8n-url $N8nHost --workflows-dir $n8nDir"
    Write-Warn "Workflow import requires manual step -- n8n API key must be configured"
}

# =============================================================================
# STEP 5 -- Restore n8n config files
# =============================================================================
Write-Step "Restoring n8n config files"

$n8nConfigDir = Join-Path $RepoRoot "claude-config\n8n"
$aiConfig = Join-Path $n8nConfigDir "ai-config.json"

if (Test-Path $aiConfig) {
    docker cp $aiConfig "n8n:/home/node/.n8n/ai-config.json"
    Write-OK "ai-config.json copied into n8n container"
} else {
    Write-Warn "ai-config.json not found -- job search pipeline will need reconfiguration"
}

# =============================================================================
# STEP 6 -- Skills and Claude config
# =============================================================================
Write-Step "Skills and Claude config"
Write-Host "  Skills are stored in Obsidian (auto-synced) and as .plugin files in claude-config\plugins\"
Write-Host "  Install plugins by double-clicking each .plugin file in:"
Write-Host "  $RepoRoot\claude-config\plugins\"
Write-Warn "Manual step required -- install each .plugin file"

# =============================================================================
# DONE
# =============================================================================
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Restore complete!" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Manual steps remaining:"
Write-Host "  1. Import n8n workflows via UI at http://localhost:5678"
Write-Host "  2. Install .plugin files from repos\claude-config\plugins\"
Write-Host "  3. Open Obsidian and confirm vault is fully synced"
Write-Host "  4. Start a Claude/Cowork session and run: --project Resume Builder"
Write-Host "     to verify memory-bootstrap loads cleanly"
