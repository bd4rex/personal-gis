param([switch]$ForceImport)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$compose = Join-Path $root "services\docker-compose.yml"
$image = "overv/openstreetmap-tile-server@sha256:b6a79da39b6d0758368f7c62d22e49dd3ec59e78b194a5ef9dee2723b1f3fa79"
$source = Join-Path $root "raw\osm\carto\jiangsu-anhui.osm.pbf"
$sourceManifest = Join-Path $root "raw\osm\carto\jiangsu-anhui.manifest.json"
$productRoot = Join-Path $root "products\osm-carto"
$manifestPath = Join-Path $productRoot "osm-carto.manifest.json"
$tileCache = Join-Path $root "data\osm-carto-tiles"
$dataVolume = "giss_osm_carto_data"

& (Join-Path $PSScriptRoot "build-osm-carto-source.ps1")
if ($LASTEXITCODE -ne 0) { throw "Preparing the OSM Carto source failed." }
New-Item -ItemType Directory -Force -Path $productRoot, $tileCache | Out-Null
$sourceState = Get-Content -Raw -LiteralPath $sourceManifest | ConvertFrom-Json
$sourceHash = [string]$sourceState.product.sha256
$current = if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
  Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
} else { $null }
docker pull $image | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Downloading the pinned OSM Carto renderer failed." }
$volumeReady = [bool](docker volume ls -q --filter "name=^${dataVolume}$")
$databaseReady = $false
$importComplete = $false
if ($volumeReady) {
  docker run --rm --entrypoint bash -v "${dataVolume}:/data/database/:ro" $image -lc "test -f /data/database/postgres/PG_VERSION"
  $databaseReady = $LASTEXITCODE -eq 0
  docker run --rm --entrypoint bash -v "${dataVolume}:/data/database/:ro" $image -lc "test -f /data/database/planet-import-complete"
  $importComplete = $LASTEXITCODE -eq 0
}
$sourceChanged = $current -and $current.source.sha256 -ne $sourceHash
$needsImport = $ForceImport -or -not $volumeReady -or -not $databaseReady -or $sourceChanged

if ($needsImport) {
  if ($volumeReady) { docker volume rm -f $dataVolume | Out-Host }
  docker volume create $dataVolume | Out-Null
  Get-ChildItem -LiteralPath $tileCache -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
  Write-Host "Importing Jiangsu and Anhui into the OSM Carto rendering database. The existing map remains available."
  docker run --rm --name giss-osm-carto-import --shm-size 1g `
    -e THREADS=4 `
    -e "OSM2PGSQL_EXTRA_ARGS=-C 4096" `
    -v "${source}:/data/region.osm.pbf:ro" `
    -v "${dataVolume}:/data/database/" `
    -v "${tileCache}:/data/tiles/" `
    $image import
  if ($LASTEXITCODE -ne 0) {
    docker run --rm --entrypoint bash -v "${dataVolume}:/data/database/:ro" $image -lc "test -f /data/database/postgres/PG_VERSION"
    if ($LASTEXITCODE -ne 0) { throw "OSM Carto database import failed before the database was created." }
    Write-Warning "The main database import succeeded, but an external dataset failed. Resuming from local downloads."
    & (Join-Path $PSScriptRoot "repair-osm-carto-external.ps1") -Image $image -DataVolume $dataVolume
    if ($LASTEXITCODE -ne 0) { throw "OSM Carto external data repair failed." }
  }
} elseif (-not $importComplete) {
  Write-Host "Resuming the preserved OSM Carto database after an interrupted external-data download."
  & (Join-Path $PSScriptRoot "repair-osm-carto-external.ps1") -Image $image -DataVolume $dataVolume
  if ($LASTEXITCODE -ne 0) { throw "OSM Carto external data repair failed." }
}

$databaseBytesText = docker run --rm --entrypoint bash -v "${dataVolume}:/data/database/:ro" $image -lc "du -sb /data/database | cut -f1"
if ($LASTEXITCODE -ne 0) { throw "Could not measure the OSM Carto database." }
$databaseBytes = [int64](($databaseBytesText | Select-Object -Last 1).Trim())
$manifest = [ordered]@{
  schemaVersion = 1
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
  renderer = [ordered]@{
    name = "OpenStreetMap Carto"
    image = $image
    tiles = "/osm-carto/tile/{z}/{x}/{y}.png"
    minZoom = 0
    maxZoom = 20
  }
  source = [ordered]@{
    file = "raw/osm/carto/jiangsu-anhui.osm.pbf"
    bytes = [int64]$sourceState.product.bytes
    sha256 = $sourceHash
    regions = @("jiangsu", "anhui")
  }
  storage = [ordered]@{
    databaseVolume = $dataVolume
    databaseBytes = $databaseBytes
    tileCache = "data/osm-carto-tiles"
  }
}
$manifestChanged = -not $current `
  -or [int]$current.schemaVersion -ne 1 `
  -or [string]$current.renderer.image -ne $image `
  -or [string]$current.source.sha256 -ne $sourceHash `
  -or [int64]$current.source.bytes -ne [int64]$sourceState.product.bytes `
  -or [int64]$current.storage.databaseBytes -ne $databaseBytes
if ($manifestChanged) {
  [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
} else {
  Write-Host "OSM Carto manifest already matches the installed database."
}

docker compose -f $compose --profile advanced up -d --build api osm-carto web
if ($LASTEXITCODE -ne 0) { throw "Starting the OSM Carto tile service failed." }
Write-Host "OSM Carto is installed. Tiles: http://localhost:8080/osm-carto/tile/{z}/{x}/{y}.png"
Get-Item -LiteralPath $manifestPath | Select-Object FullName, Length, LastWriteTime
