$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root "raw\osm\china\giss-core-latest.osm.pbf"
$directory = Join-Path $root "products\nautical"
$filtered = Join-Path $directory "seamarks.osm.pbf"
$staged = Join-Path $directory "seamarks.staged.geojson"
$target = Join-Path $directory "seamarks.geojson"
$image = "giss-osmium:1"
$utf8NoBom = New-Object Text.UTF8Encoding($false)
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Capability OSM source is missing: $source" }
if (-not (docker image ls -q $image)) {
  docker build -t $image (Join-Path $root "services\tools\osmium")
  if ($LASTEXITCODE -ne 0) { throw "Building the Osmium image failed." }
}
New-Item -ItemType Directory -Force -Path $directory | Out-Null
docker run --rm -v "${root}:/data" $image tags-filter /data/raw/osm/china/giss-core-latest.osm.pbf `
  nwr/seamark:type nwr/harbour nwr/man_made=lighthouse nwr/man_made=beacon nwr/man_made=breakwater nwr/leisure=marina `
  -o /data/products/nautical/seamarks.osm.pbf --overwrite
if ($LASTEXITCODE -ne 0) { throw "Extracting OSM nautical features failed." }
docker run --rm -v "${root}:/data" $image export /data/products/nautical/seamarks.osm.pbf `
  -f geojson -o /data/products/nautical/seamarks.staged.geojson --overwrite
if ($LASTEXITCODE -ne 0) { throw "Exporting OSM nautical GeoJSON failed." }
$payload = Get-Content -Raw -LiteralPath $staged | ConvertFrom-Json
$featureCount = @($payload.features).Count
if ($featureCount -lt 1) { throw "No nautical features were extracted from the capability source." }
Move-Item -LiteralPath $staged -Destination $target -Force
$manifest = [ordered]@{
  schemaVersion = 1
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
  sourceFile = "raw/osm/china/giss-core-latest.osm.pbf"
  sourceSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash.ToLowerInvariant()
  features = $featureCount
  bytes = (Get-Item -LiteralPath $target).Length
  sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash.ToLowerInvariant()
  attribution = "OpenStreetMap contributors"
  warning = "Reference only; not for navigation safety decisions"
}
[IO.File]::WriteAllText((Join-Path $directory "nautical.manifest.json"), ($manifest | ConvertTo-Json -Depth 5), $utf8NoBom)
Get-Item -LiteralPath $target | Select-Object FullName, Length, LastWriteTime
