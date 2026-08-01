$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$migrationDir = Join-Path $root "services\postgis\migrations"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker was not found on PATH."
}

function Assert-NativeSuccess([string]$Operation) {
  if ($LASTEXITCODE -ne 0) { throw "$Operation failed with exit code $LASTEXITCODE." }
}

docker exec giss-postgis psql -v ON_ERROR_STOP=1 -U gis -d personal_gis -c @"
CREATE TABLE IF NOT EXISTS public.app_schema_migrations (
  version text PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT now()
);
"@ | Out-Host
Assert-NativeSuccess "Creating the migration ledger"

Get-ChildItem $migrationDir -Filter "*.sql" -File | Sort-Object Name | ForEach-Object {
  $version = $_.BaseName.Replace("'", "''")
  $alreadyApplied = docker exec giss-postgis psql -U gis -d personal_gis -tAc `
    "SELECT 1 FROM public.app_schema_migrations WHERE version='$version'"
  Assert-NativeSuccess "Checking migration $version"

  if ("$alreadyApplied".Trim() -eq "1") {
    Write-Host "Migration $version already applied."
    return
  }

  Write-Host "Applying migration $version..."
  docker exec giss-postgis psql -v ON_ERROR_STOP=1 -U gis -d personal_gis `
    -f "/migrations/$($_.Name)" | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "Migration $version failed."
  }
  docker exec giss-postgis psql -v ON_ERROR_STOP=1 -U gis -d personal_gis -c `
    "INSERT INTO public.app_schema_migrations(version) VALUES ('$version')" | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "Could not record migration $version."
  }
}
