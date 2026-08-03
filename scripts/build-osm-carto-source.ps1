param([switch]$Force)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$image = "giss-osmium:1"
$sourceRoot = Join-Path $root "raw\osm\china\provinces"
$outputRoot = Join-Path $root "raw\osm\carto"
$output = Join-Path $outputRoot "jiangsu-anhui.osm.pbf"
$staged = Join-Path $outputRoot "jiangsu-anhui.staged.osm.pbf"
$manifestPath = Join-Path $outputRoot "jiangsu-anhui.manifest.json"
$inputs = @(
  Join-Path $sourceRoot "jiangsu-latest.osm.pbf"
  Join-Path $sourceRoot "anhui-latest.osm.pbf"
)

foreach ($input in $inputs) {
  if (-not (Test-Path -LiteralPath $input -PathType Leaf)) { throw "OSM Carto input is missing: $input" }
}
if (-not (docker image ls -q $image)) {
  docker build -t $image (Join-Path $root "services\tools\osmium")
  if ($LASTEXITCODE -ne 0) { throw "Could not build the local osmium image." }
}
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

$inputEntries = @($inputs | ForEach-Object {
  $item = Get-Item -LiteralPath $_
  [ordered]@{
    file = $item.FullName.Substring($root.Length + 1).Replace('\', '/')
    bytes = $item.Length
    sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.FullName).Hash.ToLowerInvariant()
  }
})
$inputSignature = ($inputEntries | ForEach-Object { $_.sha256 }) -join ':'
$current = if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
  Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
} else { $null }
if (-not $Force -and $current -and $current.inputSignature -eq $inputSignature -and
    (Test-Path -LiteralPath $output -PathType Leaf)) {
  Write-Host "OSM Carto source already matches the current Jiangsu and Anhui snapshots."
  Get-Item -LiteralPath $output, $manifestPath | Select-Object FullName, Length, LastWriteTime
  exit 0
}

Remove-Item -LiteralPath $staged -Force -ErrorAction SilentlyContinue
$containerInputs = @($inputs | ForEach-Object { "/data/$($_.Substring($root.Length + 1).Replace('\', '/'))" })
docker run --rm -v "${root}:/data" $image merge @containerInputs -o /data/raw/osm/carto/jiangsu-anhui.staged.osm.pbf --overwrite
if ($LASTEXITCODE -ne 0) { throw "Merging Jiangsu and Anhui for OSM Carto failed." }
docker run --rm -v "${root}:/data" $image fileinfo -e /data/raw/osm/carto/jiangsu-anhui.staged.osm.pbf | Out-Host
if ($LASTEXITCODE -ne 0) { throw "The merged OSM Carto source is invalid." }
Move-Item -LiteralPath $staged -Destination $output -Force

$outputInfo = Get-Item -LiteralPath $output
$manifest = [ordered]@{
  schemaVersion = 1
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
  scope = @("jiangsu", "anhui")
  inputSignature = $inputSignature
  inputs = $inputEntries
  product = [ordered]@{
    file = "raw/osm/carto/jiangsu-anhui.osm.pbf"
    bytes = $outputInfo.Length
    sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $output).Hash.ToLowerInvariant()
  }
}
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
Get-Item -LiteralPath $output, $manifestPath | Select-Object FullName, Length, LastWriteTime
