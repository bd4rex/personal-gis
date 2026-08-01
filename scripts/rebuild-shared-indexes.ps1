param(
  [switch]$Plan,
  [switch]$ConfirmRebuild,
  [int]$ValhallaTimeoutMinutes = 360,
  [int]$NominatimTimeoutMinutes = 1440,
  [ValidateRange(2, 8)][int]$BuildCpus = 4,
  [ValidateRange(4, 10)][int]$BuildMemoryGB = 6,
  [string]$MaintenanceJobId = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$services = Join-Path $root "services"
$compose = Join-Path $services "docker-compose.yml"
$envFile = Join-Path $services ".env"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$audit = Join-Path $root "runtime\index-rebuild\$timestamp"
$capabilityRoot = Join-Path $root "raw\osm\china"
$capabilitySource = Join-Path $capabilityRoot "giss-core-latest.osm.pbf"
$activeRoutingDefault = Join-Path $root "products\routing\valhalla"
$routingVersions = Join-Path $root "products\routing\versions"
$candidateRouting = Join-Path $audit "candidate-valhalla"
$candidateRoutingFinal = Join-Path $routingVersions $timestamp
$statePath = Join-Path $root "data\maintenance\shared-index-state.json"
$candidateNominatimVolume = "giss_nominatim_candidate_$timestamp"
$candidateNominatimContainer = "giss-nominatim-candidate-$timestamp"
$candidateValhallaContainer = "giss-valhalla-candidate-$timestamp"
$nominatimImage = "mediagis/nominatim@sha256:7923a8e67197fc6d4f4ecb7c0e8bbedffeddcfdf4519596fe946e46a28f5a9f8"
$valhallaImage = "ghcr.io/valhalla/valhalla-scripted@sha256:3d7a08f7e78b356ee873b61711b743ad81bcc114b0ca5731217da8bba6ba39d1"
$utf8 = New-Object Text.UTF8Encoding($false)
$report = [ordered]@{
  schemaVersion = 2
  strategy = "blue-green"
  mapAvailableDuringBuild = $true
  startedAt = [DateTimeOffset]::Now.ToString("o")
  success = $false
  switched = $false
  error = $null
}
$previousNominatimVolume = $null
$previousRoutingPath = $null
$routingPromoted = $false

function Assert-NativeSuccess([string]$Operation) {
  if ($LASTEXITCODE -ne 0) { throw "$Operation failed with exit code $LASTEXITCODE." }
}

function Read-DotEnv {
  $values = @{}
  if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) { return $values }
  foreach ($line in Get-Content -LiteralPath $envFile) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') { $values[$matches[1]] = $matches[2] }
  }
  return $values
}

function Set-DotEnvValue([string]$Name, [string]$Value) {
  $lines = if (Test-Path -LiteralPath $envFile -PathType Leaf) { [Collections.Generic.List[string]](Get-Content -LiteralPath $envFile) } else { [Collections.Generic.List[string]]::new() }
  $updated = $false
  for ($index = 0; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -match "^\s*$([regex]::Escape($Name))=") {
      $lines[$index] = "$Name=$Value"
      $updated = $true
      break
    }
  }
  if (-not $updated) { $lines.Add("$Name=$Value") }
  [IO.File]::WriteAllLines($envFile, $lines, $utf8)
}

function Invoke-Compose([string[]]$Arguments, [string]$Operation) {
  Push-Location $services
  try {
    & docker compose --env-file $envFile -f $compose --profile advanced @Arguments
    Assert-NativeSuccess $Operation
  }
  finally { Pop-Location }
}

function Get-ActiveMount([string]$Container, [string]$Destination, [string]$Property) {
  $inspect = (docker inspect $Container | ConvertFrom-Json)[0]
  Assert-NativeSuccess "Inspecting $Container"
  $mount = $inspect.Mounts | Where-Object { $_.Destination -eq $Destination } | Select-Object -First 1
  if (-not $mount) { throw "$Container does not mount $Destination." }
  return [string]$mount.$Property
}

function Wait-ContainerEndpoint([string]$Container, [string]$Url, [int]$TimeoutMinutes, [string]$Label) {
  $attempts = [math]::Max(1, $TimeoutMinutes * 6)
  for ($attempt = 0; $attempt -lt $attempts; $attempt++) {
    $state = ((docker inspect --format '{{.State.Status}}' $Container 2>$null) -join "").Trim()
    if ($state -eq "exited" -or $state -eq "dead") { throw "$Label candidate exited before validation." }
    docker exec $Container curl -fsS --max-time 8 $Url *> $null
    if ($LASTEXITCODE -eq 0) { return }
    if ($attempt -gt 0 -and $attempt % 6 -eq 0) {
      Write-Host "$Label candidate is still building; the active map remains available."
      docker logs --since 70s --tail 12 $Container 2>&1 | ForEach-Object { Write-Host $_ }
    }
    Start-Sleep -Seconds 10
  }
  throw "$Label candidate did not become ready within $TimeoutMinutes minutes."
}

function Wait-Healthy([string]$Container, [int]$TimeoutMinutes) {
  $attempts = [math]::Max(1, $TimeoutMinutes * 6)
  for ($attempt = 0; $attempt -lt $attempts; $attempt++) {
    $state = ((docker inspect --format '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}' $Container 2>$null) -join "").Trim()
    if ($state -eq "running|healthy") { return }
    if ($state -like "exited|*" -or $state -like "dead|*") { throw "$Container exited while activating the candidate." }
    Start-Sleep -Seconds 10
  }
  throw "$Container did not become healthy within $TimeoutMinutes minutes."
}

function Remove-CandidateContainers {
  foreach ($container in @($candidateNominatimContainer, $candidateValhallaContainer)) {
    docker rm -f $container *> $null
  }
}

function Restore-ActivePointers {
  if (-not $previousNominatimVolume -or -not $previousRoutingPath) { return }
  Set-DotEnvValue "NOMINATIM_VOLUME_NAME" $previousNominatimVolume
  Set-DotEnvValue "VALHALLA_DATA_PATH" ($previousRoutingPath -replace '\\', '/')
  Invoke-Compose @("up", "-d", "--force-recreate", "nominatim", "valhalla") "Restoring the previous shared indexes"
  Wait-Healthy "giss-nominatim" 20
  Wait-Healthy "giss-valhalla" 20
  Invoke-Compose @("up", "-d", "--force-recreate", "api") "Refreshing the API after rollback"
  Wait-Healthy "giss-api" 10
  Invoke-Compose @("up", "-d", "--force-recreate", "web") "Refreshing the web entry after rollback"
  Wait-Healthy "giss-web" 5
}

if ($Plan) {
  [pscustomobject]@{
    Action = "Build isolated search and routing candidates, validate, then switch"
    Availability = "The current map, search and routing services stay online during the build"
    CandidateMemoryLimit = "${BuildMemoryGB}GB"
    CandidateCpuLimit = $BuildCpus
    CapabilitySource = $capabilitySource
    Command = "D:\GISS\rebuild-shared-indexes.cmd -ConfirmRebuild"
  } | Format-List
  exit 0
}
if (-not $ConfirmRebuild) { throw "Re-run with -ConfirmRebuild after reviewing -Plan output." }
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw "Docker is required." }
docker info *> $null
Assert-NativeSuccess "Checking Docker"

New-Item -ItemType Directory -Force -Path $audit, $routingVersions, (Split-Path -Parent $statePath) | Out-Null
if ($MaintenanceJobId) { [IO.File]::WriteAllText((Join-Path $audit "maintenance-job-id.txt"), $MaintenanceJobId, $utf8) }

try {
  $previousNominatimVolume = Get-ActiveMount "giss-nominatim" "/var/lib/postgresql/16/main" "Name"
  $previousRoutingPath = Get-ActiveMount "giss-valhalla" "/custom_files" "Source"
  if (-not $previousNominatimVolume -or -not $previousRoutingPath) { throw "The active index pointers could not be identified." }
  $report.previous = [ordered]@{ nominatimVolume = $previousNominatimVolume; valhallaPath = $previousRoutingPath }

  Write-Host "Building a shared source snapshot; active services remain online..."
  & (Join-Path $PSScriptRoot "build-capability-source.ps1")
  if (-not (Test-Path -LiteralPath $capabilitySource -PathType Leaf)) { throw "The shared source snapshot was not created." }

  Write-Host "Building Valhalla candidate in isolation; active routing remains online..."
  New-Item -ItemType Directory -Force -Path $candidateRouting | Out-Null
  Copy-Item -LiteralPath $capabilitySource -Destination (Join-Path $candidateRouting "giss-core-latest.osm.pbf") -Force
  $elevationSource = Join-Path $previousRoutingPath "elevation_data"
  if (Test-Path -LiteralPath $elevationSource -PathType Container) {
    robocopy $elevationSource (Join-Path $candidateRouting "elevation_data") /E /COPY:DAT /DCOPY:T /R:2 /W:2 /NFL /NDL /NJH /NJS | Out-Null
    if ($LASTEXITCODE -gt 7) { throw "Copying reusable elevation data failed with exit code $LASTEXITCODE." }
  }
  $valhallaArgs = @(
    "run", "-d", "--name", $candidateValhallaContainer,
    "--label", "giss.role=shared-index-candidate",
    "--label", "giss.maintenance-job=$MaintenanceJobId",
    "--memory", "4g", "--memory-swap", "5g", "--cpus", ([string][math]::Min(3, $BuildCpus)),
    "-e", "use_tiles_ignore_pbf=False", "-e", "force_rebuild=True", "-e", "build_elevation=True",
    "-e", "build_admins=True", "-e", "build_time_zones=True", "-e", "build_tar=True",
    "-e", "server_threads=3", "-e", "use_default_speeds_config=True", "-e", "TZ=Asia/Shanghai",
    "-v", "${candidateRouting}:/custom_files", $valhallaImage
  )
  & docker @valhallaArgs | Out-Null
  Assert-NativeSuccess "Starting the Valhalla candidate"
  Wait-ContainerEndpoint $candidateValhallaContainer "http://127.0.0.1:8002/status" $ValhallaTimeoutMinutes "Valhalla"
  if (-not (Test-Path -LiteralPath (Join-Path $candidateRouting "valhalla_tiles.tar") -PathType Leaf)) { throw "Valhalla candidate has no tile archive." }
  docker stop -t 30 $candidateValhallaContainer | Out-Null
  Assert-NativeSuccess "Stopping the validated Valhalla candidate"

  Write-Host "Building Nominatim candidate in an isolated, resource-limited volume; active search remains online..."
  $dotenv = Read-DotEnv
  if (-not $dotenv.ContainsKey("NOMINATIM_PASSWORD") -or -not $dotenv.NOMINATIM_PASSWORD) { throw "NOMINATIM_PASSWORD is missing from services/.env." }
  & docker volume create --label "giss.role=shared-index-candidate" --label "giss.maintenance-job=$MaintenanceJobId" $candidateNominatimVolume | Out-Null
  Assert-NativeSuccess "Creating the Nominatim candidate volume"
  $nominatimArgs = @(
    "run", "-d", "--name", $candidateNominatimContainer,
    "--label", "giss.role=shared-index-candidate", "--label", "giss.maintenance-job=$MaintenanceJobId",
    "--memory", "${BuildMemoryGB}g", "--memory-swap", "$($BuildMemoryGB + 1)g", "--cpus", ([string]$BuildCpus), "--shm-size", "1g",
    "-e", "PBF_PATH=/data/giss-core-latest.osm.pbf", "-e", "UPDATE_MODE=none", "-e", "FREEZE=true",
    "-e", "IMPORT_STYLE=extratags", "-e", "IMPORT_WIKIPEDIA=false", "-e", "THREADS=3", "-e", "GUNICORN_WORKERS=2",
    "-e", "NOMINATIM_PASSWORD=$($dotenv.NOMINATIM_PASSWORD)", "-e", "POSTGRES_SHARED_BUFFERS=1GB",
    "-e", "POSTGRES_MAINTENANCE_WORK_MEM=1GB", "-e", "POSTGRES_AUTOVACUUM_WORK_MEM=256MB",
    "-e", "POSTGRES_WORK_MEM=24MB", "-e", "POSTGRES_EFFECTIVE_CACHE_SIZE=4GB", "-e", "POSTGRES_MAX_WAL_SIZE=2GB",
    "-e", "TZ=Asia/Shanghai", "-v", "${candidateNominatimVolume}:/var/lib/postgresql/16/main",
    "-v", "${capabilityRoot}:/data:ro", $nominatimImage
  )
  & docker @nominatimArgs | Out-Null
  Assert-NativeSuccess "Starting the Nominatim candidate"
  Wait-ContainerEndpoint $candidateNominatimContainer "http://127.0.0.1:8080/status" $NominatimTimeoutMinutes "Nominatim"

  Write-Host "Validating candidate databases before switching..."
  docker exec -u nominatim $candidateNominatimContainer nominatim check-database
  Assert-NativeSuccess "Checking the Nominatim candidate database"
  foreach ($coordinate in @("32.0603,118.7969", "52.5200,13.4050")) {
    $parts = $coordinate.Split(',')
    $response = docker exec $candidateNominatimContainer curl -fsS --max-time 20 "http://127.0.0.1:8080/reverse?lat=$($parts[0])&lon=$($parts[1])&format=jsonv2"
    Assert-NativeSuccess "Testing Nominatim coverage at $coordinate"
    if (-not (($response -join "") | ConvertFrom-Json).display_name) { throw "Nominatim returned no result at $coordinate." }
  }

  Write-Host "Promoting validated candidates and switching active pointers..."
  docker rm $candidateValhallaContainer | Out-Null
  docker rm -f $candidateNominatimContainer | Out-Null
  Move-Item -LiteralPath $candidateRouting -Destination $candidateRoutingFinal
  $routingPromoted = $true
  Set-DotEnvValue "NOMINATIM_VOLUME_NAME" $candidateNominatimVolume
  Set-DotEnvValue "VALHALLA_DATA_PATH" ($candidateRoutingFinal -replace '\\', '/')
  $switchStarted = Get-Date
  Invoke-Compose @("up", "-d", "--force-recreate", "nominatim", "valhalla") "Activating the validated shared indexes"
  Wait-Healthy "giss-nominatim" 20
  Wait-Healthy "giss-valhalla" 20
  Invoke-Compose @("up", "-d", "--force-recreate", "api") "Refreshing the API index mounts"
  Wait-Healthy "giss-api" 10
  Invoke-Compose @("up", "-d", "--force-recreate", "web") "Refreshing the local web entry"
  Wait-Healthy "giss-web" 5

  $report.switched = $true
  $report.switchSeconds = [math]::Round(((Get-Date) - $switchStarted).TotalSeconds, 1)
  $report.active = [ordered]@{ nominatimVolume = $candidateNominatimVolume; valhallaPath = $candidateRoutingFinal }
  $report.success = $true
  $state = [ordered]@{
    schemaVersion = 1
    strategy = "blue-green"
    status = "active"
    activatedAt = [DateTimeOffset]::Now.ToString("o")
    active = $report.active
    previous = $report.previous
    source = $capabilitySource
    lastBuildMapAvailable = $true
    switchSeconds = $report.switchSeconds
  }
  [IO.File]::WriteAllText($statePath, ($state | ConvertTo-Json -Depth 6), $utf8)
  Write-Host "Candidate indexes are active. The old versions are retained for rollback."
}
catch {
  $report.error = $_.Exception.Message
  Write-Warning "Candidate rebuild failed. The previously active map indexes remain selected."
  Remove-CandidateContainers
  if ($report.switched -or $routingPromoted) {
    try { Restore-ActivePointers }
    catch { Write-Warning "Automatic pointer rollback also failed: $($_.Exception.Message)" }
  }
  throw
}
finally {
  $report.completedAt = [DateTimeOffset]::Now.ToString("o")
  [IO.File]::WriteAllText((Join-Path $audit "report.json"), ($report | ConvertTo-Json -Depth 8), $utf8)
}
