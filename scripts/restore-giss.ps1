param(
  [Parameter(Mandatory = $true)][string]$BackupDirectory
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$backupRoot = (Resolve-Path (Join-Path $root "backups")).Path.TrimEnd('\')
$target = (Resolve-Path $BackupDirectory).Path

function Assert-NativeSuccess([string]$Operation) {
  if ($LASTEXITCODE -ne 0) { throw "$Operation failed with exit code $LASTEXITCODE." }
}

if (-not $target.StartsWith($backupRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
  throw "BackupDirectory must be inside $backupRoot"
}

$dump = Join-Path $target "personal_gis.dump"
$manifest = Join-Path $target "manifest.json"
$mediaBackup = Join-Path $target "media"
$mediaRoot = Join-Path $root "data\media"
if (-not (Test-Path $dump) -or -not (Test-Path $manifest)) {
  throw "The backup is incomplete."
}

$parsedManifest = Get-Content -Raw $manifest | ConvertFrom-Json
$entries = @($parsedManifest)
if ($entries.Count -eq 0) {
  throw "The backup manifest is empty."
}
foreach ($entry in $entries) {
  $relative = [string]$entry.Path
  if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|/)\.\.(/|$)') {
    throw "Unsafe path in backup manifest: $relative"
  }
  $file = Join-Path $target $relative.Replace('/', '\')
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
    throw "Backup file is missing: $relative"
  }
  $resolvedFile = (Resolve-Path -LiteralPath $file).Path
  if (-not $resolvedFile.StartsWith($target + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Backup file resolves outside the selected directory: $relative"
  }
  if ((Get-Item -LiteralPath $resolvedFile).Length -ne [int64]$entry.Bytes) {
    throw "Backup size verification failed: $relative"
  }
  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedFile).Hash.ToLowerInvariant()
  if ($actual -ne ([string]$entry.SHA256).ToLowerInvariant()) {
    throw "Backup checksum verification failed: $relative"
  }
}

$services = Join-Path $root "services"
Push-Location $services
try {
  docker compose stop api martin | Out-Host
  Assert-NativeSuccess "Stopping API and Martin"
  docker cp $dump "giss-postgis:/tmp/personal_gis.dump"
  Assert-NativeSuccess "Copying the restore dump"
  try {
    docker exec giss-postgis pg_restore -U gis -d personal_gis --clean --if-exists --no-owner /tmp/personal_gis.dump | Out-Host
    Assert-NativeSuccess "Restoring PostgreSQL"
  }
  finally {
    docker exec giss-postgis rm -f /tmp/personal_gis.dump 2>$null
  }
  & (Join-Path $PSScriptRoot "migrate-giss.ps1")
  if (Test-Path $mediaBackup) {
    New-Item -ItemType Directory -Force -Path $mediaRoot | Out-Null
    Get-ChildItem -LiteralPath $mediaBackup -Force | Copy-Item -Destination $mediaRoot -Recurse -Force
  }
  docker compose up -d api martin web | Out-Host
  Assert-NativeSuccess "Restarting API, Martin, and web"
}
finally {
  Pop-Location
}

Write-Host "Restore completed from $target"
