param(
  [Parameter(Mandatory = $true)]
  [string]$KitDirectory
)

$ErrorActionPreference = "Stop"
$kit = (Resolve-Path -LiteralPath $KitDirectory).Path.TrimEnd('\')
$manifestPath = Join-Path $kit "manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath)) {
  throw "Offline-kit manifest is missing: $manifestPath"
}

$parsedManifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$entries = @($parsedManifest)
if ($entries.Count -lt 1) { throw "Offline-kit manifest is empty." }
$verificationPath = Join-Path $kit "verification.json"
if (Test-Path -LiteralPath $verificationPath) {
  Remove-Item -LiteralPath $verificationPath -Force
}
$kitInfoPath = Join-Path $kit "kit-info.json"
if (-not (Test-Path -LiteralPath $kitInfoPath -PathType Leaf)) { throw "Offline-kit metadata is missing." }
$kitInfo = Get-Content -Raw -LiteralPath $kitInfoPath | ConvertFrom-Json

$verifiedBytes = [int64]0
foreach ($entry in $entries) {
  $relative = ([string]$entry.Path).Replace('\', '/')
  $segments = @($relative.Split('/'))
  if ([IO.Path]::IsPathRooted($relative) -or $relative.Contains(':') -or
      $segments.Count -lt 1 -or $segments -contains '..' -or $segments -contains '.' -or
      $segments -contains '') {
    throw "Unsafe path in offline-kit manifest: $relative"
  }
  # Avoid GetFullPath here: deeply nested browser assets can exceed legacy MAX_PATH.
  $candidate = Join-Path $kit $relative.Replace('/', '\')
  if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
    throw "Offline-kit file is missing: $relative"
  }
  $file = Get-Item -LiteralPath $candidate
  if ($file.Length -ne [int64]$entry.Bytes) {
    throw "Offline-kit size mismatch: $relative"
  }
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $candidate).Hash.ToLowerInvariant()
  if ($hash -ne ([string]$entry.SHA256).ToLowerInvariant()) {
    throw "Offline-kit checksum mismatch: $relative"
  }
  $verifiedBytes += $file.Length
}

if ($kitInfo.advancedCapabilities) {
  foreach ($relative in @(
    "payload/GISS/raw/osm/china/giss-core-latest.osm.pbf",
    "payload/GISS/raw/osm/china/giss-core.manifest.json",
    "payload/GISS/products/routing/valhalla/valhalla_tiles.tar",
    "payload/GISS/products/encyclopedia/encyclopedia.manifest.json"
  )) {
    if (-not ($entries.Path -contains $relative)) { throw "Advanced offline-kit payload is incomplete: $relative" }
  }
}
if (@($kitInfo.operationalResources).Count) {
  foreach ($relative in @(
    "payload/GISS/web/assets/overview/overview.manifest.json",
    "payload/GISS/products/weather/latest.geojson",
    "payload/GISS/products/weather/weather.manifest.json",
    "payload/GISS/products/nautical/seamarks.geojson",
    "payload/GISS/products/nautical/nautical.manifest.json",
    "payload/GISS/products/encyclopedia/travel-guide.manifest.json"
  )) {
    if (-not ($entries.Path -contains $relative)) { throw "Operational offline-kit payload is incomplete: $relative" }
  }
  $wikipedia = @($entries.Path | Where-Object { $_ -like "payload/GISS/products/encyclopedia/wikipedia_zh_all_*.zim" })
  $wikivoyage = @($entries.Path | Where-Object { $_ -like "payload/GISS/products/encyclopedia/wikivoyage_zh_all_*.zim" })
  if ($wikipedia.Count -lt 1 -or $wikivoyage.Count -lt 1) {
    throw "Operational offline-kit knowledge archives are incomplete."
  }
}
if ($kitInfo.nominatimIndexIncluded -and -not ($entries.Path -contains $kitInfo.nominatimIndexArchive)) {
  throw "Offline-kit metadata references a missing Nominatim index archive."
}
if ($kitInfo.osmCartoIncluded) {
  foreach ($relative in @(
    [string]$kitInfo.osmCartoArchive,
    "payload/GISS/products/osm-carto/osm-carto.manifest.json",
    "payload/GISS/raw/osm/carto/jiangsu-anhui.osm.pbf"
  )) {
    if (-not $relative -or -not ($entries.Path -contains $relative)) {
      throw "OSM Carto offline-kit payload is incomplete: $relative"
    }
  }
}

$verification = [ordered]@{
  schemaVersion = 1
  status = "verified"
  verifiedAt = (Get-Date).ToUniversalTime().ToString("o")
  manifestSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $manifestPath).Hash.ToLowerInvariant()
  files = $entries.Count
  bytes = $verifiedBytes
}
$verificationTempPath = "$verificationPath.tmp"
$verificationJson = $verification | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText($verificationTempPath, $verificationJson, [Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $verificationTempPath -Destination $verificationPath -Force

[pscustomobject]@{
  Status = "verified"
  Kit = $kit
  Files = $entries.Count
  Bytes = $verifiedBytes
  GiB = [math]::Round($verifiedBytes / 1GB, 2)
}
